# Opensource VPN Server for Enterprise 
Ý tưởng ban đầu:
Tạo một vpn server cho doanh nghiệp có hơn 10000 nhân sự.
Mục tiêu hoạt động an toàn, ổn định, cảnh báo, phát hiện xâm nhập bảo vệ toàn bộ công ty. 
- Sử dụng Wireguard
- Có docker-compose.yml để quản lý container ghi log data
- Thích ứng linh hoạt trong trường hợp vừa bị tấn công, vừa phải vận hành hệ thống liên tục
- Có cách ly khi gặp sự cố.
- Có biện pháp dự phòng khi bị tấn công, mất kết nối, là lá chắn thép đầu tiên bảo vệ các server khác trong doanh nghiệp.



## 🌟 Tính năng chính
## 🏗️ Kiến trúc hệ thống
## 🚀 Cài đặt nhanh
## 📁 Cấu trúc dự án
## 🔧 Quản lý hệ thống
## 🔒 Bảo mật
## 📊 Giám sát & Báo cáo
## 🗃️ Database Schema
## 🔧 Cấu hình nâng cao
## 🐛 Troubleshooting
## 📝 License
## 🤝 Đóng góp
## Roadmap
### PHASE 1: LỚP CORE VPN
- ✅ Cài đặt cấu hình Wireguard
### PHASE 2: LỚP BẢO MẬT
- ✅ Cài nginx cấu hình để ghi logs
- ✅ Cấu hình nginx để làm load balancer (3 wireguard server)
- [x] Cài fail2ban để phòng chống tấn công brute force.
### PHASE 3: LỚP QUẢN LÝ
### PHASE 4: LỚP GIÁM SÁT
