# Use a very small web server image
FROM nginx:alpine

# Copy your public folder into nginx's default html folder
COPY public/ /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Start nginx (it will automatically serve /usr/share/nginx/html)
CMD ["nginx", "-g", "daemon off;"]
