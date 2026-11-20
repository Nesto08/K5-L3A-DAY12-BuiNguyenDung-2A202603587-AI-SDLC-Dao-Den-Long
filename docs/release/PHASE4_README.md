# Đảo Đèn Lồng — Release guide (Phase 4)

> File hướng dẫn phát hành riêng. Sáu Markdown gốc của Coach không bị chỉnh sửa.

## Yêu cầu
Godot 4.7.x (bản desktop), Python 3.10+, `psutil` (`python -m pip install psutil`) cho phép đo RSS.

## Chạy game
Từ gốc repository:

```sh
godot --path daodenlong res://scenes/main.tscn
```

## Build / smoke check

```sh
godot --headless --path daodenlong --editor --quit
python tests/run_phase4_tests.py
python tests/run_phase2_tests.py
python tests/run_phase3_tests.py
```

## Input & options
A / D trái-phải, W / S tiến-lùi, Space nhảy, Shift lướt, E tương tác, Q tỏa sáng, Esc menu, R chơi lại. Có đổi phím, chế độ màu dễ phân biệt, giảm chuyển động, chữ lớn. Khi kết thúc có thể nhập tên hợp lệ để lưu điểm; bảng Top 10 trong menu.

## Headless / bench / soak

```sh
godot --quiet --headless --path daodenlong --script res://scripts/headless_runner.gd -- --night 1 --seed 42 --ticks 600 --out sample.jsonl
python tests/bench_phase4.py --seed 42 --duration 30 --out bench.json
python tests/soak_phase4.py --seed 7 --nights 10 --out soak.json
```

Benchmark dùng cửa sổ thực 1280×720, không chạy `--headless`. Số đo FPS chỉ có giá trị trên phần cứng/driver/renderer đã chạy, không được coi là kết quả máy chấm. Bench đo hạt/đối tượng chuẩn, không tính cây trang trí; hiệu ứng trang trí tắt trong benchmark. Soak dùng 10 Đêm liên tiếp trong một tiến trình Godot và lấy RSS ở hai lần reset qua `psutil`.

Xuất leaderboard:

```sh
godot --headless --path daodenlong --script res://scripts/export_leaderboard.gd -- --export-leaderboard out.json
```

File bảng điểm được lưu trong `user://lantern_leaderboard.json` nên tồn tại sau khi thoát game.

## Giới hạn / kết quả cần xác minh
Giao diện và các command chưa được xác nhận bằng Godot 4.7.2 trong môi trường tạo gói. Kiểm tra game chạy thật và FPS thực, không tự báo PASS nếu chưa chạy. Benchmark/soak phải chạy chính command trong `game.contract.json`. Tự bổ sung ảnh/video demo và phần retro/AI token thực tế trước phát hành.

## Chính sách test hồi quy
Test Phase 2 và Phase 3 được giữ các assertion về hành vi còn hợp lệ; version, thời gian và điểm đã được thay bằng giá trị mới do Ticket-03/04 thay thế. Không bỏ test âm thầm.
