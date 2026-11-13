# Menggunakan image resmi Nginx yang ringan berbasis Alpine Linux
FROM nginx:alpine

# Menyalin file index.html ke direktori public html default Nginx
COPY index.html /usr/share/nginx/html/index.html

# Membuka port 80 untuk akses web
EXPOSE 80