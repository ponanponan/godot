import http.server
import socketserver
import os
import ssl
import gzip
import io

# 指定服务器的路径
server_directory = "./"  # 替换为你想要的目录路径
os.chdir(server_directory)

# 设置服务器端口
PORT = 443

# 自定义请求处理器，支持 Gzip
class GzipHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        """ 处理 GET 请求，优先提供 Gzip 版本的 .wasm, .pck, .js 文件 """
        file_path = self.path.lstrip("/")  # 移除前导 '/'
        gz_path = file_path + ".gz"  # 尝试查找 .gz 版本

        # 如果 .gz 版本存在，返回 .gz 文件，并正确设置 Header
        if os.path.exists(gz_path):
            self.send_response(200)
            self.send_header("Content-Encoding", "gzip")  # 让浏览器自动解压
            self.send_header("Content-Type", self.guess_type(file_path))
            self.send_header("Content-Length", str(os.path.getsize(gz_path)))
            self.end_headers()
            with open(gz_path, "rb") as f:
                self.wfile.write(f.read())
            return

        # 如果没有 .gz 版本，返回原始文件
        super().do_GET()

# 创建 SSL 上下文
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(certfile="cert.pem", keyfile="key.pem")

# 启动 HTTPS 服务器
with socketserver.TCPServer(("", PORT), GzipHTTPRequestHandler) as httpd:
    httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
    print(f"Serving HTTPS with Gzip on port {PORT}...")
    httpd.serve_forever()
