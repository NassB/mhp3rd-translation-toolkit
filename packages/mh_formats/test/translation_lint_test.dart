import 'package:mh_formats/mh_formats.dart';
import 'package:test/test.dart';

const rathalos = GlossaryEntry(
  sourceTerm: 'リオレウス',
  targetTerm: 'Rathalos',
  mandatory: true,
);
const hunter = GlossaryEntry(sourceTerm: 'ハンター', targetTerm: 'Chasseur');

List<LintKind> kinds(List<LintIssue> l) => [for (final i in l) i.kind];

void main() {
  test('a clean translation has no issue', () {
    expect(lintTranslation(source: 'un\ndeux', target: 'one\ntwo'), isEmpty);
  });

  test('empty translation: only a warning, and only for a non-empty source',
      () {
    final i = lintTranslation(source: 'abc', target: '');
    expect(
      i,
      [const LintIssue(LintKind.emptyTranslation, LintSeverity.warning)],
    );
    expect(lintTranslation(source: '', target: ''), isEmpty);
    expect(lintTranslation(source: '  ', target: ''), isEmpty);
  });

  test('control codes ~Xnn must be kept (error), order aside', () {
    const src = '~C02Texte~C00';
    expect(lintTranslation(source: src, target: '~C02Text~C00'), isEmpty);
    expect(lintTranslation(source: src, target: '~C00 x ~C02'), isEmpty);
    final lost = lintTranslation(source: src, target: '~C02Texte');
    expect(lost, [
      const LintIssue(
        LintKind.controlCodes,
        LintSeverity.error,
        'missing ~C00',
      ),
    ]);
    final extra = lintTranslation(source: 'a', target: 'a~B00');
    expect(extra.single.detail, 'extra ~B00');
    // Un code altéré = un manquant et un en trop.
    final bent = lintTranslation(source: src, target: '~C2Texte~C00');
    expect(bent.single.detail, startsWith('missing ~C02'));
    expect(controlCodesOf('~C05 a ~B00 ~C05'), ['~B00', '~C05', '~C05']);
  });

  test('newline count must match the source (error)', () {
    final i = lintTranslation(source: 'a\nb\nc', target: 'a\nb');
    expect(i, [
      const LintIssue(
        LintKind.newlineCount,
        LintSeverity.error,
        'source=2 target=1',
      ),
    ]);
    expect(kinds(lintTranslation(source: 'a', target: 'a\nb')), [
      LintKind.newlineCount,
    ]);
  });

  test('NUL is an error', () {
    expect(
      kinds(lintTranslation(source: 'a', target: 'a\u0000')),
      [LintKind.nulChar],
    );
  });

  test('leading and trailing space must match the source', () {
    expect(
      lintTranslation(source: 'a', target: ' a ').map((e) => e.detail),
      ['leading', 'trailing'],
    );
    expect(lintTranslation(source: ' a ', target: ' a '), isEmpty);
    expect(
      lintTranslation(source: ' a', target: 'a').map((e) => e.detail),
      ['leading'],
    );
  });

  test('mandatory terms are warnings, others only suggestions', () {
    const glossary = [rathalos, hunter];
    final missing = lintTranslation(
      source: 'リオレウスとハンター',
      target: 'Le dragon et le joueur',
      glossary: glossary,
    );
    expect(missing, [
      const LintIssue(LintKind.mandatoryTerm, LintSeverity.warning, 'Rathalos'),
      const LintIssue(LintKind.suggestedTerm, LintSeverity.info, 'Chasseur'),
    ]);
    expect(
      lintTranslation(
        source: 'リオレウスとハンター',
        target: 'Rathalos et Chasseur',
        glossary: glossary,
      ),
      isEmpty,
    );
    // Terme absent de la source : rien à exiger.
    expect(
      lintTranslation(source: 'abc', target: 'def', glossary: glossary),
      isEmpty,
    );
  });

  test('matchGlossary returns the terms present in the source', () {
    expect(matchGlossary('xリオレウスx', [rathalos, hunter]), [rathalos]);
    expect(matchGlossary('rien', [rathalos]), isEmpty);
    expect(
      matchGlossary(
        'abc',
        [const GlossaryEntry(sourceTerm: '', targetTerm: 'x')],
      ),
      isEmpty,
    );
  });

  test('French spacing is off by default and checked on request', () {
    expect(lintTranslation(source: 'a', target: 'Quoi?'), isEmpty);
    const on = LintOptions(frenchSpacing: true);
    List<String> details(String t) => [
          for (final i in lintTranslation(source: 'a', target: t, options: on))
            if (i.kind == LintKind.frenchSpacing) i.detail,
        ];
    expect(details('Quoi?'), ['?']);
    expect(details('Quoi ?'), ['?']); // espace ordinaire : pas insécable
    expect(details('Quoi\u00A0?'), isEmpty);
    expect(details('Quoi !'), isEmpty);
    expect(details('Voici :\nsuite'), [':']);
    expect(details('Vraiment\u00A0?!'), isEmpty); // ponctuation doublée
    expect(details('?début'), isEmpty); // pas de caractère avant
  });

  test('invisible and control characters absent from the source are errors',
      () {
    List<LintIssue> of(String s, String t) => [
          for (final i in lintTranslation(source: s, target: t))
            if (i.kind == LintKind.invisibleChar) i,
        ];
    expect(
      of('あ', 'a\u200Bb\tc\u200B'),
      [
        const LintIssue(
          LintKind.invisibleChar,
          LintSeverity.error,
          'U+0009 U+200B',
        ),
      ],
    );
    for (final c in [
      '\u200C',
      '\u200D',
      '\uFEFF',
      '\u0001',
      '\u007F',
      '\u0085',
      '\r',
    ]) {
      expect(
        of('あ', 'a${c}b'),
        hasLength(1),
        reason: codePointLabel(c.runes.first),
      );
    }
    expect(of('あ\nい', 'a\nb'), isEmpty); // \n est un jeton, pas un défaut
    expect(of('あ\tい', 'a\tb'), isEmpty); // présent dans la source
    expect(of('あ\tい', 'a\tb\tc'), hasLength(1)); // un de trop
    expect(of('あ', 'a\u00A0: b'), isEmpty); // espace insécable visible
  });

  test('kana and kanji left in a translation are a warning', () {
    final issues = lintTranslation(source: 'リオレウス', target: 'Le リオ火竜');
    expect(
      issues,
      contains(
        const LintIssue(LintKind.residualJapanese, LintSeverity.warning, '4'),
      ),
    );
    expect(
      lintTranslation(source: 'あ', target: 'Il dit « oui »… ！'),
      isNot(
        contains(
          predicate<LintIssue>(
            (i) => i.kind == LintKind.residualJapanese,
          ),
        ),
      ),
    );
    expect(isJapaneseRune('ｱ'.runes.first), isTrue); // demi-chasse
    expect(isJapaneseRune('ー'.runes.first), isTrue);
    expect(isJapaneseRune('【'.runes.first), isFalse);
  });

  test('characters outside the displayable set are info, only on request', () {
    final known = {for (var c = 0x20; c <= 0x7E; c++) c, ...'é«»'.runes};
    final opts = LintOptions(displayableChars: known);
    List<LintIssue> of(String t) => [
          for (final i
              in lintTranslation(source: 'あ', target: t, options: opts))
            if (i.kind == LintKind.unmeasuredChar) i,
        ];
    expect(
      of('Œuvre ≪x≫ œ【y】\u3000z'),
      [
        const LintIssue(
          LintKind.unmeasuredChar,
          LintSeverity.info,
          'U+0152 U+0153 U+226A U+226B U+3000 U+3010 U+3011',
        ),
      ],
    );
    expect(of('« été »\nok'), isEmpty);
    // Invisibles et japonais ont leurs propres constats : pas de doublon.
    expect(of('a\u200Bbリ'), isEmpty);
    expect(
      lintTranslation(source: 'あ', target: 'Œuvre'),
      isEmpty,
      reason: 'sans ensemble fourni, aucun contrôle',
    );
  });

  test('issues are value objects', () {
    const a = LintIssue(LintKind.newlineCount, LintSeverity.error, 'x');
    const b = LintIssue(LintKind.newlineCount, LintSeverity.error, 'x');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
