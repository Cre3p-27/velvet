// VELVET · services/romanise.js
// LYRICS → ROMANISE: Latin letters for Japanese kana and Korean hangul, so a
// line you cannot read can still be sung along to.
//
//   kana   → Hepburn (きゃ kya, しゃ sha, っ doubles the next consonant,
//            ー lengthens the vowel before it, ん n)
//   hangul → Revised Romanization, syllable by syllable (no sound changes
//            across syllables — a letter-by-letter reading, not phonetics)
//
// Kanji and Chinese characters need a dictionary to be read and are left as
// they are; everything that is not kana or hangul passes through untouched.
.pragma library

const KANA = {
    "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
    "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
    "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
    "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
    "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
    "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
    "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
    "や": "ya", "ゆ": "yu", "よ": "yo",
    "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
    "わ": "wa", "ゐ": "wi", "ゑ": "we", "を": "o", "ん": "n",
    "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
    "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
    "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
    "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
    "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
    "ゔ": "vu",
    "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
    "ゃ": "ya", "ゅ": "yu", "ょ": "yo", "ゎ": "wa"
};

// Two kana that read as one sound.
const PAIRS = {
    "きゃ": "kya", "きゅ": "kyu", "きょ": "kyo",
    "しゃ": "sha", "しゅ": "shu", "しょ": "sho", "しぇ": "she",
    "ちゃ": "cha", "ちゅ": "chu", "ちょ": "cho", "ちぇ": "che",
    "にゃ": "nya", "にゅ": "nyu", "にょ": "nyo",
    "ひゃ": "hya", "ひゅ": "hyu", "ひょ": "hyo",
    "みゃ": "mya", "みゅ": "myu", "みょ": "myo",
    "りゃ": "rya", "りゅ": "ryu", "りょ": "ryo",
    "ぎゃ": "gya", "ぎゅ": "gyu", "ぎょ": "gyo",
    "じゃ": "ja", "じゅ": "ju", "じょ": "jo", "じぇ": "je",
    "ぢゃ": "ja", "ぢゅ": "ju", "ぢょ": "jo",
    "びゃ": "bya", "びゅ": "byu", "びょ": "byo",
    "ぴゃ": "pya", "ぴゅ": "pyu", "ぴょ": "pyo",
    "ふぁ": "fa", "ふぃ": "fi", "ふぇ": "fe", "ふぉ": "fo",
    "てぃ": "ti", "でぃ": "di", "とぅ": "tu", "どぅ": "du",
    "うぃ": "wi", "うぇ": "we", "うぉ": "wo",
    "ゔぁ": "va", "ゔぃ": "vi", "ゔぇ": "ve", "ゔぉ": "vo",
    "つぁ": "tsa", "つぃ": "tsi", "つぇ": "tse", "つぉ": "tso"
};

// Katakana is hiragana shifted by 0x60 (ァ…ヶ); fold it first.
function toHiragana(ch) {
    const c = ch.charCodeAt(0);
    if (c >= 0x30A1 && c <= 0x30F6)
        return String.fromCharCode(c - 0x60);
    return ch;
}

function kana(text) {
    let out = "";
    let doubled = false;
    const chars = Array.from(text);
    for (let i = 0; i < chars.length; i++) {
        const ch = toHiragana(chars[i]);
        const next = i + 1 < chars.length ? toHiragana(chars[i + 1]) : "";
        // っ / ッ: double the consonant that follows.
        if (ch === "っ") {
            doubled = true;
            continue;
        }
        // ー: repeat the vowel before it.
        if (chars[i] === "ー") {
            const m = out.match(/[aeiou]$/);
            out += m ? m[0] : "";
            continue;
        }
        let piece = PAIRS[ch + next];
        if (piece !== undefined)
            i++;
        else
            piece = KANA[ch];
        if (piece === undefined) {
            doubled = false;
            out += chars[i];
            continue;
        }
        // ん before a vowel or y is written n' so it cannot be misread.
        if (ch === "ん" && /^[aeiouy]/.test(KANA[next] ?? PAIRS[next] ?? ""))
            piece = "n'";
        if (doubled) {
            piece = (piece.startsWith("ch") ? "t" : piece.charAt(0)) + piece;
            doubled = false;
        }
        out += piece;
    }
    return out;
}

const L = ["g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "", "j", "jj", "ch", "k", "t", "p", "h"];
const V = ["a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae", "oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"];
const T = ["", "k", "k", "k", "n", "n", "n", "t", "l", "k", "m", "l", "l", "l", "p", "l", "m", "p", "p", "t", "t", "ng", "t", "t", "k", "t", "p", "t"];

function hangul(text) {
    let out = "";
    for (const ch of text) {
        const c = ch.charCodeAt(0) - 0xAC00;
        if (c < 0 || c > 11171) {
            out += ch;
            continue;
        }
        const t = c % 28;
        const v = Math.floor(c / 28) % 21;
        const l = Math.floor(c / 588);
        out += L[l] + V[v] + T[t];
    }
    return out;
}

// Does the line hold anything this can read?
function readable(text) {
    return /[぀-ヿ가-힣]/.test(text);
}

function romanise(text) {
    if (!text || !readable(text))
        return text;
    return hangul(kana(text));
}
