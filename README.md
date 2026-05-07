<div align="center">
  <img src="https://img.icons8.com/color/96/000000/voice-recognition.png" alt="VocalizeAI Logo" />
  <h1>VocalizeAI</h1>
  <p><strong>Nền tảng Xử lý Đa phương tiện Ngoại tuyến Chuyên nghiệp: Speech-to-Text, Dịch thuật & Text-to-Speech</strong></p>
  
  <p>
    <img src="https://img.shields.io/badge/Flutter-Frontend-02569B?style=flat-square&logo=flutter" alt="Flutter" />
    <img src="https://img.shields.io/badge/Python-Backend-3776AB?style=flat-square&logo=python" alt="Python" />
    <img src="https://img.shields.io/badge/Faster_Whisper-STT-FF6F00?style=flat-square" alt="Whisper" />
    <img src="https://img.shields.io/badge/Piper-TTS-4CAF50?style=flat-square" alt="Piper" />
  </p>
</div>

<hr />

<h2>✨ Tổng Quan Dự Án</h2>
<p>
  <b>VocalizeAI</b> là một ứng dụng máy tính để bàn (Desktop) mạnh mẽ, được thiết kế để xử lý các quy trình âm thanh phức tạp hoàn toàn ngoại tuyến. Được xây dựng với giao diện người dùng hiện đại, mượt mà bằng Flutter, ứng dụng giao tiếp liền mạch với một backend Python hiệu suất cao thông qua FastAPI.
</p>
<p>
  Ứng dụng sử dụng các mô hình AI tiên tiến nhất hiện nay, bao gồm <b>faster-whisper</b> cho khả năng chuyển đổi Giọng nói thành Văn bản (STT) với độ chính xác cao và <b>Piper CLI</b> để tạo Giọng nói từ Văn bản (TTS) chất lượng phòng thu. Tất cả đều chạy hoàn toàn trên máy tính cục bộ, đảm bảo tối đa quyền riêng tư dữ liệu và hiệu năng.
</p>

<h2>🚀 Tính Năng Nổi Bật</h2>
<ul>
  <li>🎙️ <b>Speech-to-Text (STT):</b> Trích xuất văn bản và tạo phụ đề tự động (SRT) từ các tệp âm thanh (MP3, WAV, M4A, FLAC) sử dụng mô hình faster-whisper tối ưu.</li>
  <li>🌍 <b>Dịch thuật (Translate):</b> Dịch văn bản ngoại tuyến hỗ trợ nhiều ngôn ngữ (Tiếng Anh, Tiếng Việt, Tiếng Pháp, Tiếng Tây Ban Nha, Tiếng Trung).</li>
  <li>🗣️ <b>Text-to-Speech (TTS):</b> Tạo các đoạn âm thanh chất lượng cao từ văn bản hoặc tệp SRT sử dụng Piper TTS, hỗ trợ nhiều giọng đọc khác nhau.</li>
  <li>⚡ <b>Xử Lý Ngoại Tuyến (Offline):</b> Toàn bộ mô hình được tải xuống và lưu trữ cache cục bộ, đảm bảo không phụ thuộc vào kết nối mạng sau lần cài đặt đầu tiên.</li>
  <li>🎨 <b>Giao Diện Cao Cấp (Premium UI/UX):</b> Thiết kế Glassmorphism tuyệt đẹp với hình nền động (animated backgrounds) và theo dõi trạng thái hệ thống theo thời gian thực.</li>
  <li>⚙️ <b>Quản Lý Backend Tự Động:</b> Ứng dụng Flutter tự động khởi chạy và quản lý vòng đời của máy chủ AI Python ngầm, người dùng không cần chạy lệnh thủ công.</li>
</ul>

<h2>🛠️ Kiến Trúc Hệ Thống</h2>
<table width="100%">
  <tr>
    <td width="50%"><b>Frontend</b></td>
    <td width="50%"><b>Backend</b></td>
  </tr>
  <tr>
    <td>
      <ul>
        <li>Framework: <b>Flutter</b></li>
        <li>Quản lý Trạng thái: Stateful / TickerProvider</li>
        <li>Giao diện: Custom Glassmorphism Theme</li>
      </ul>
    </td>
    <td>
      <ul>
        <li>Framework: <b>FastAPI</b> & Python 3</li>
        <li>Engine STT: <b>faster-whisper</b> (large-v3)</li>
        <li>Engine TTS: <b>Piper TTS</b> (ONNX)</li>
      </ul>
    </td>
  </tr>
</table>

<h2>📦 Cài Đặt & Thiết Lập</h2>

<h3>1. Yêu cầu hệ thống</h3>
<ul>
  <li><b>Flutter SDK</b> (Khuyến nghị bản v3.19+)</li>
  <li><b>Python 3.10+</b></li>
  <li><b>FFmpeg</b> (Bắt buộc phải có để xử lý âm thanh với thư viện pydub)</li>
</ul>

<h3>2. Thiết lập Backend</h3>
<p>Mở Terminal, điều hướng đến thư mục <code>backend</code>, thiết lập môi trường ảo và cài đặt các thư viện cần thiết:</p>
<pre><code>cd backend
python3 -m venv venv
source venv/bin/activate  # Trên Windows sử dụng: venv\Scripts\activate
pip install -r requirements.txt
</code></pre>

<p><i>Tùy chọn: Đóng gói backend thành một tệp thực thi độc lập (executable) để không cần chạy script:</i></p>
<pre><code>bash build.sh
</code></pre>

<h3>3. Thiết lập Frontend</h3>
<p>Quay lại thư mục gốc của dự án, tải các gói Flutter và chạy ứng dụng:</p>
<pre><code>cd ..
flutter pub get
flutter run -d macos  # hoặc windows / linux tùy hệ điều hành của bạn
</code></pre>

<h2>📖 Hướng Dẫn Sử Dụng</h2>
<ol>
  <li><b>Khởi động Ứng dụng:</b> Mở ứng dụng VocalizeAI. Giao diện Flutter sẽ tự động cố gắng khởi chạy máy chủ AI backend. Vui lòng đợi thanh trạng thái thay đổi từ <i>"Starting AI Engine..."</i> sang sẵn sàng hoạt động.</li>
  <li><b>Chức năng STT (Speech-to-Text):</b>
    <ul>
      <li>Chuyển đến tab <b>STT</b> trên thanh điều hướng.</li>
      <li>Nhấp để duyệt hoặc kéo-thả trực tiếp một tệp âm thanh vào vùng tải lên.</li>
      <li>Nhấn nút <b>Extract Text (STT)</b>. Ứng dụng sẽ xử lý và xuất ra phụ đề định dạng SRT. Bạn có thể sao chép kết quả trực tiếp bằng nút copy.</li>
    </ul>
  </li>
  <li><b>Chức năng Translate (Dịch thuật):</b>
    <ul>
      <li>Chuyển đến tab <b>Translate</b>.</li>
      <li>Dán văn bản hoặc toàn bộ nội dung tệp SRT của bạn vào khung văn bản, chọn ngôn ngữ nguồn và ngôn ngữ đích.</li>
      <li>Nhấn <b>Translate Text</b> để nhận bản dịch mong muốn. Dữ liệu sẽ tự động được lưu trữ vào thư mục ứng dụng của bạn.</li>
    </ul>
  </li>
  <li><b>Chức năng TTS (Text-to-Speech):</b>
    <ul>
      <li>Chuyển đến tab <b>TTS</b>.</li>
      <li>Nhập văn bản mới hoặc tải lên một tệp SRT có sẵn.</li>
      <li>Chọn giọng đọc và nhấn nút bắt đầu tạo âm thanh. Ứng dụng sẽ kết xuất âm thanh cục bộ và cung cấp cho bạn một tệp WAV chất lượng phòng thu.</li>
    </ul>
  </li>
</ol>

<hr />
<div align="center">
  <p><i>Được thiết kế và phát triển với ❤️ nhằm tối ưu hóa năng suất và bảo vệ quyền riêng tư người dùng.</i></p>
</div>
