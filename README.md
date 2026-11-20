# Phase 1 — Đảo Đèn Lồng

Hướng dẫn chạy, điều khiển, luật và kiểm thử: [README_PHASE1.md](README_PHASE1.md).

---

# Day 12 â€” AI SDLC: Äáº£o ÄÃ¨n Lá»“ng

> **CÃ¡ nhÃ¢n** (1 ngÆ°á»i / 1 MSSV) Â· Ãp dá»¥ng SDLC cÃ¹ng AI Ä‘á»ƒ xÃ¢y má»™t **game 3D** qua **4 phase**, tá»« yÃªu cáº§u ban Ä‘áº§u tá»›i báº£n phÃ¡t hÃ nh.
> **Lab board + trá»£ giáº£ng:** **[Äáº£o ÄÃ¨n Lá»“ng Lab](https://claude.ai/artifact/Q1RYyv1dxjUczzCbd2ZnoW)**

---

## TÃ i liá»‡u cá»§a lab

| File | Ná»™i dung |
|---|---|
| [GUIDE.md](GUIDE.md) | HÆ°á»›ng dáº«n lÃ m lab: vÃ²ng lÃ m viá»‡c má»—i phase, harness, kiá»ƒm chá»©ng, token |
| [CHECKPOINTS.md](CHECKPOINTS.md) | CÃ¡c má»‘c tá»± kiá»ƒm tra tá»« chuáº©n bá»‹ Ä‘áº¿n ná»™p bÃ i |
| [SUBMISSION.md](SUBMISSION.md) | Äáº·t tÃªn repo, háº¡n ná»™p, tag, Release, video, checklist |
| [RULES.md](RULES.md) | Quy Ä‘á»‹nh: AI, trung thá»±c vá» báº±ng chá»©ng, báº£n quyá»n, báº£o máº­t |
| [RUBRIC.md](RUBRIC.md) | Thang Ä‘iá»ƒm chi tiáº¿t |

## Lab board

YÃªu cáº§u dá»± Ã¡n Ä‘Æ°á»£c phÃ¡t hÃ nh táº¡i **[Äáº£o ÄÃ¨n Lá»“ng Lab](https://claude.ai/artifact/Q1RYyv1dxjUczzCbd2ZnoW)**. Má»—i phase lÃ  má»™t tab (tab chÆ°a phÃ¡t hÃ nh bá»‹ khÃ³a), má»—i tab cÃ³ trá»£ giáº£ng AI riÃªng chá»‰ tráº£ lá»i trong pháº¡m vi phase Ä‘Ã³. Trá»£ giáº£ng cáº§n Ä‘Äƒng nháº­p claude.ai vÃ  dÃ¹ng lÆ°á»£t Claude cá»§a báº¡n.

## Dá»± Ã¡n

**Äáº£o ÄÃ¨n Lá»“ng**: game 3D gÃ³c nhÃ¬n thá»© ba. MÃ¢y, ngÆ°á»i giá»¯ Ä‘Ã¨n nhá» tuá»•i, gom Ä‘om Ä‘Ã³m Ä‘á»ƒ tháº¯p láº¡i cÃ¡c ÄÃ¨n Lá»“ng Lá»›n vÃ  nÃ© BÃ³ng Má»±c trong sÆ°Æ¡ng Ä‘en.

- KhÃ´ng rÃ ng buá»™c cÃ´ng nghá»‡; cháº¡y Ä‘Æ°á»£c trÃªn macOS hoáº·c Linux.
- TuÃ¢n theo **Test Contract** (cháº¿ Ä‘á»™ headless) Ä‘á»ƒ Ä‘Æ°á»£c cháº¥m tá»± Ä‘á»™ng vÃ  so sÃ¡nh vá»›i nhau.

| Phase | Báº¡n nháº­n | Ná»™p |
|---|---|---|
| 1 | **PRD-0** (mÃ´ táº£ tá»•ng quÃ¡t) + Test Contract | tag `phase-1` |
| 2 | **Ticket-02**, phÃ¡t hÃ nh khi Phase 1 káº¿t thÃºc | tag `phase-2` |
| 3 | **Ticket-03**, phÃ¡t hÃ nh khi Phase 2 káº¿t thÃºc | tag `phase-3` |
| 4 | **Ticket-04**, phÃ¡t hÃ nh khi Phase 3 káº¿t thÃºc | tag `phase-4` + Release `v1.0.0` |

YÃªu cáº§u sáº½ Ä‘Æ°á»£c bá»• sung vÃ  cÃ³ thá»ƒ thay Ä‘á»•i giá»¯a cÃ¡c phase, giá»‘ng dá»± Ã¡n tháº­t.

### Lá»‹ch 4 giá»

BÃ i lab kÃ©o dÃ i **4 giá»**. Phase 1 vÃ  2 khoáº£ng **1 giá»**, Phase 3 khoáº£ng **30 phÃºt**, Phase 4 khoáº£ng **1 giá» 30 phÃºt**. Má»—i phase phÃ¡t hÃ nh Ä‘Ãºng má»‘c giá». Phase má»›i xuáº¥t hiá»‡n trÃªn lab board khi tá»›i má»‘c.

| Má»‘c | Sá»± kiá»‡n | Háº¡n tag |
|---|---|---|
| 0h | PhÃ¡t hÃ nh **Phase 1** (PRD-0), gá»“m cáº£ pháº§n chuáº©n bá»‹ | `phase-1` trÆ°á»›c má»‘c 1h |
| 1h | PhÃ¡t hÃ nh **Phase 2** | `phase-2` trÆ°á»›c má»‘c 2h |
| 2h | PhÃ¡t hÃ nh **Phase 3** | `phase-3` trÆ°á»›c má»‘c 2h30 |
| 2h30 | PhÃ¡t hÃ nh **Phase 4** | `phase-4`, Release `v1.0.0` vÃ  video trÆ°á»›c má»‘c 4h |
| 4h | Háº¿t giá» lab, chá»‘t bÃ i | |

Háº¿t giá» má»—i phase thÃ¬ tag vÃ  chuyá»ƒn sang phase tiáº¿p theo, dÃ¹ phase chÆ°a hoÃ n háº£o. Chá»— chÆ°a xong ghi trung thá»±c trong báº±ng chá»©ng.

---

## Gá»£i Ã½ SDLC (cÃ¡ch lÃ m lÃ  cá»§a báº¡n)

Má»—i phase lÃ  má»™t vÃ²ng nhá». CÃ´ng cá»¥, thá»© tá»±, Ä‘á»‹nh dáº¡ng tÃ i liá»‡u Ä‘á»u tá»± do; Ä‘Ã¢y chá»‰ lÃ  gá»£i Ã½:

1. **Requirements:** biáº¿n yÃªu cáº§u thÃ nh tiÃªu chÃ­ nghiá»‡m thu kiá»ƒm chá»©ng Ä‘Æ°á»£c. Chá»— mÆ¡ há»“ thÃ¬ tá»± giáº£ Ä‘á»‹nh vÃ  ghi láº¡i.
2. **Plan:** nghÄ© cÃ¡ch kiá»ƒm chá»©ng **trÆ°á»›c** khi Ä‘á»ƒ agent viáº¿t code.
3. **Build:** Ä‘á»ƒ agent viáº¿t, báº¡n Ä‘iá»u phá»‘i vÃ  review.
4. **Verify:** cháº¡y tháº­t, kiá»ƒm tra hÃ nh vi tháº­t. *KhÃ´ng cÃ³ báº±ng chá»©ng thÃ¬ chÆ°a xong*: "agent báº£o cháº¡y rá»“i" khÃ´ng pháº£i báº±ng chá»©ng.
5. **Evaluate:** cÃ¡i gÃ¬ Ä‘áº¡t, AI sai á»Ÿ Ä‘Ã¢u, harness (AGENTS.md, skill, hook) cáº§n chá»‰nh gÃ¬.
6. **Release:** gáº¯n tag.

## Ba Ä‘iá»u cáº§n nhá»›

> Báº¡n Ä‘Æ°á»£c **tá»± do sÃ¡ng táº¡o thÃªm** quanh pháº§n lÃµi (nhÃ¢n váº­t, cÆ¡ cháº¿ nhá», cÃ¢u chuyá»‡n, hiá»‡u á»©ng, Ã¢m thanhâ€¦). SÃ¡ng táº¡o gá»n vÃ  khÃ´ng phÃ¡ yÃªu cáº§u Ä‘Æ°á»£c tÃ­nh Ä‘iá»ƒm trong háº¡ng má»¥c F cá»§a [RUBRIC](RUBRIC.md); ghi má»¥c "SÃ¡ng táº¡o cá»§a tÃ´i" trong README cá»§a báº¡n.

- **Game tá»‘t lÃ  game Ä‘Ãºng yÃªu cáº§u cá»§a khÃ¡ch hÃ ng**, khÃ´ng pháº£i game phá»©c táº¡p hay Ä‘áº¹p nháº¥t. LÃ m Ä‘Ãºng vÃ  chá»©ng minh Ä‘Æ°á»£c lÃ  Ä‘Ãºng trÆ°á»›c, trau chuá»‘t sau.
- **CÃ¢n nháº¯c ká»¹ quota token cá»§a báº¡n.** Äá»‘t nhiá»u token khÃ´ng lÃ m bÃ i tá»‘t hÆ¡n. Ngá»¯ cáº£nh gá»n, káº¿ hoáº¡ch rÃµ, kiá»ƒm chá»©ng sá»›m thÆ°á»ng vá»«a ráº» vá»«a Ä‘Ãºng hÆ¡n cháº¡y agent liÃªn tá»¥c.
- **Kiá»ƒm chá»©ng lÃ  pháº§n quan trá»ng nháº¥t.** Báº±ng chá»©ng (test, output headless, áº£nh, sá»‘ Ä‘o) Ä‘Ã¡ng giÃ¡ hÆ¡n lá»i mÃ´ táº£.

---

## BÃ n giao cuá»‘i cÃ¹ng

Má»™t **repo GitHub cÃ¡ nhÃ¢n, public**, gá»“m:

1. **ToÃ n bá»™ mÃ£ nguá»“n** cá»§a game qua 4 phase, tag `phase-1` â€¦ `phase-4`, Release `v1.0.0`.
2. **Video demo `.mp4` dÆ°á»›i 5 phÃºt** (Ä‘Ã­nh kÃ¨m Release `v1.0.0` hoáº·c `docs/demo/demo.mp4`, link á»Ÿ Ä‘áº§u README): chÆ¡i thá»­ vÃ  cho tháº¥y báº±ng chá»©ng game cháº¡y Ä‘Ãºng.
3. **Báº±ng chá»©ng kiá»ƒm chá»©ng** cá»§a tá»«ng phase (Ä‘á»‹nh dáº¡ng tá»± chá»n).
4. **Harness AI Ä‘Ã£ dÃ¹ng** (AGENTS.md / CLAUDE.md, skills, hooks, pluginsâ€¦), giá»¯ nguyÃªn trong repo vÃ  lá»‹ch sá»­ git.
5. **Ghi chÃ©p ngáº¯n:** spec/giáº£ Ä‘á»‹nh má»—i phase, nháº­t kÃ½ dÃ¹ng AI (gá»“m token/chi phÃ­ Æ°á»›c tÃ­nh), retro.

KhÃ´ng commit API key, token hay `.env`. Gá»­i link repo theo hÆ°á»›ng dáº«n cá»§a Coach.

## ÄÃ¡nh giÃ¡ (100 Ä‘iá»ƒm)

| Háº¡ng má»¥c | Äiá»ƒm |
|---|---|
| Test tá»± Ä‘á»™ng áº©n (headless, gá»“m kiá»ƒm tra láº¡i phase trÆ°á»›c) | 30 |
| Kiá»ƒm chá»©ng & báº±ng chá»©ng cá»§a báº¡n | 20 |
| Quy trÃ¬nh SDLC & harness AI | 15 |
| Evaluation & retro (gá»“m cÃ¡ch báº¡n dÃ¹ng token) | 10 |
| Hiá»‡u nÄƒng & á»•n Ä‘á»‹nh | 10 |
| Cháº¥t lÆ°á»£ng sáº£n pháº©m (Ä‘Ãºng yÃªu cáº§u, chÆ¡i Ä‘Æ°á»£c) | 10 |
| Video demo | 5 |

## Quy Ä‘á»‹nh

- DÃ¹ng AI thoáº£i mÃ¡i; khÃ´ng sao chÃ©p repo cá»§a ngÆ°á»i khÃ¡c.
- Báº±ng chá»©ng pháº£i tháº­t: test luÃ´n Ä‘áº¡t hay output sá»­a tay lÃ  vi pháº¡m.
- NhÃ¢n váº­t, bá»‘i cáº£nh lÃ  báº£n gá»‘c cá»§a lab; asset bÃªn ngoÃ i chá»‰ dÃ¹ng loáº¡i CC0/CC-BY/MIT hoáº·c tá»± táº¡o, ghi nguá»“n trong `CREDITS.md`.

