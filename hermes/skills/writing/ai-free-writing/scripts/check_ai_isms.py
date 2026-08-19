#!/usr/bin/env python3
"""check_ai_isms.py — quét văn bản tìm dấu hiệu AI-ism (hard-ban rules).

Usage:
    check_ai_isms.py <file>       # quét file
    cat text.txt | check_ai_isms.py   # hoặc đọc stdin

Exit code: 0 = sạch, 1 = có vi phạm.
Giới hạn: bắt từ vựng blacklist, dấu câu, khuôn cấm, từ nối đầu câu.
KHÔNG bắt được: giọng điệu, rule of three, elegant variation — quét tay bắt buộc.
"""
import re
import sys

# --- Blacklist EN (word-boundary, case-insensitive; prefix stem + \w* để bắt biến thể) ---
EN_STEMS = [
    "additionally", "moreover", "furthermore", "consequently", "notably",
    "delve", "tapestry", "testament", "pivotal", "crucial", "vital",
    "underscore", "emphasiz", "highlight", "showcas", "vibrant", "bolster",
    "foster", "enhanc", "garner", "intricate", "interplay", "meticulous",
    "enduring", "boasts", "groundbreaking", "seamless", "cutting-edge",
]
EN_PHRASES = [
    "serves as", "stands as", "functions as", "deep dive", "align with",
    "evolving landscape", "focal point", "indelible mark", "rich tapestry",
]

# --- Blacklist VI (cụm cố định, case-insensitive) ---
VI_PHRASES = [
    "đáng chú ý là", "điều đáng nói là", "hơn nữa", "bên cạnh đó", "ngoài ra",
    "tóm lại", "có thể thấy rằng", "không thể phủ nhận rằng",
    "đóng vai trò then chốt", "đóng vai trò quan trọng", "minh chứng rõ ràng",
    "bước ngoặt", "bức tranh toàn cảnh", "dấu ấn khó phai", "ăn sâu",
    "chìa khóa thành công", "nền tảng vững chắc", "đồng hành cùng",
    "không ngừng phát triển", "khẳng định vị thế", "mang tính đột phá",
]

# --- Khuôn cấm ---
FORBIDDEN_PATTERNS = [
    (r"\bnot only\b", "khuôn 'not only...but also'"),
    (r"không chỉ", "khuôn 'không chỉ...mà còn'"),
    (r"không phải[^.!?\n]{0,60}?mà (?:là )?", "khuôn 'không phải X mà là Y'"),
]

# --- Từ nối đầu câu (hard ban: mỗi lần xuất hiện là vi phạm) ---
SENTENCE_OPENERS_HARD = [
    r"^\s*Additionally\b", r"^\s*Moreover\b", r"^\s*Furthermore\b",
    r"^\s*Consequently\b", r"^\s*Notably\b",
    r"^\s*Đáng chú ý là\b", r"^\s*Hơn nữa\b", r"^\s*Tóm lại\b",
    r"^\s*Có thể thấy rằng\b",
]
# Từ nối đầu câu: chỉ vi phạm khi LẶP (quá 1 lần trong toàn văn bản)
SENTENCE_OPENERS_REPEAT = [
    r"^\s*Ngoài ra\b", r"^\s*Bên cạnh đó\b", r"^\s*Do đó\b", r"^\s*Vì vậy\b",
]

# --- Dấu câu ---
EM_DASH_SPACED = re.compile(r"(?<!\w) — | – ")
EM_DASH = "—"


def main() -> int:
    text = ""
    if len(sys.argv) > 1:
        with open(sys.argv[1], encoding="utf-8") as f:
            text = f.read()
    else:
        text = sys.stdin.read()

    violations: list[tuple[int, str, str]] = []  # (line, type, matched)
    lines = text.splitlines()
    low_lines = [ln.lower() for ln in lines]
    full_low = text.lower()

    # Blacklist EN theo dòng
    for stem in EN_STEMS:
        pat = re.compile(r"\b" + re.escape(stem) + r"\w*\b", re.IGNORECASE)
        for i, ln in enumerate(lines, 1):
            for m in pat.finditer(ln):
                violations.append((i, f"blacklist-EN: {stem}", m.group(0)))
    for phrase in EN_PHRASES:
        pat = re.compile(re.escape(phrase), re.IGNORECASE)
        for i, ln in enumerate(low_lines, 1):
            for m in pat.finditer(ln):
                violations.append((i, f"blacklist-EN: {phrase}", m.group(0)))

    # Blacklist VI
    for phrase in VI_PHRASES:
        pat = re.compile(re.escape(phrase), re.IGNORECASE)
        for i, ln in enumerate(low_lines, 1):
            for m in pat.finditer(ln):
                violations.append((i, f"blacklist-VI: {phrase}", m.group(0)))

    # Khuôn cấm
    for pat_str, label in FORBIDDEN_PATTERNS:
        pat = re.compile(pat_str, re.IGNORECASE)
        for i, ln in enumerate(lines, 1):
            for m in pat.finditer(ln):
                violations.append((i, label, m.group(0)[:80]))

    # Từ nối đầu câu
    for pat_str in SENTENCE_OPENERS_HARD:
        pat = re.compile(pat_str, re.IGNORECASE | re.MULTILINE)
        for i, ln in enumerate(lines, 1):
            if pat.match(ln):
                violations.append((i, "từ nối đầu câu (hard ban)", pat.match(ln).group(0).strip()))
    for pat_str in SENTENCE_OPENERS_REPEAT:
        pat = re.compile(pat_str, re.IGNORECASE | re.MULTILINE)
        hits = [(i, ln) for i, ln in enumerate(lines, 1) if pat.match(ln)]
        if len(hits) > 1:
            for i, ln in hits:
                violations.append((i, "từ nối đầu câu (lặp lại)", pat.match(ln).group(0).strip()))

    # Em dash spaced
    for i, ln in enumerate(lines, 1):
        for m in EM_DASH_SPACED.finditer(ln):
            violations.append((i, "em dash có khoảng trắng", m.group(0)))

    # Em dash tổng (giới hạn 1 / 500 từ)
    word_count = len(re.findall(r"\S+", text))
    em_total = text.count(EM_DASH)
    limit = max(1, word_count // 500)
    if em_total > limit:
        violations.append((0, f"em dash vượt giới hạn {limit} (có {em_total} / {word_count} từ)", ""))

    # Báo cáo
    if not violations:
        print(f"Sạch — {word_count} từ, không tìm thấy AI-ism.")
        return 0
    seen = set()
    for line, typ, matched in violations:
        key = (line, typ, matched)
        if key in seen:
            continue
        seen.add(key)
        loc = f"L{line}: " if line else ""
        print(f"{loc}[{typ}] {matched}")
    print(f"\n{len(seen)} vi phạm — văn bản CHƯA sạch. Quét tay thêm: giọng điệu, rule of three, elegant variation, ca ngợi không dữ kiện.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
