Here is a **step-by-step guide** to deploy a **Flutter web app**:

### Prerequisites:
1. **Flutter installed**: Ensure Flutter is installed and web support is enabled. Verify by running:
   ```bash
   flutter --version
   flutter config --enable-web
   ```

2. **Build the Web App**:
   Compile your Flutter web app by running:
   ```bash
   flutter build web
   ```
   This generates the `build/web` directory, containing the app ready for deployment.

---

### 1. **Web Server Deployment**

#### Option 1: Deploying with **Nginx**

1. **Install Nginx**:
   On an Ubuntu server, install Nginx with:
   ```bash
   sudo apt update
   sudo apt install nginx
   ```

2. **Configure Nginx**:
   Open the Nginx configuration file:
   ```bash
   sudo nano /etc/nginx/sites-available/default
   ```

   Replace the content with the following (ensure the correct path to your Flutter files is used):
   ```nginx
   server {
       listen 80;
       server_name your_domain_or_ip;

       root /path/to/your/flutter/app/build/web;
       index index.html;

       location / {
           try_files $uri $uri/ /index.html;
       }
   }
   ```

3. **Set Permissions**:
   Make sure that Nginx can access the app files:
   ```bash
   sudo chmod -R 755 /path/to/your/flutter/app/build/web
   sudo chown -R www-data:www-data /path/to/your/flutter/app/build/web
   ```

4. **Restart Nginx**:
   After configuring, restart Nginx to apply the changes:
   ```bash
   sudo systemctl restart nginx
   ```

5. **Test the App**:
   Visit your server's IP or domain in a browser to ensure your Flutter app is running.

#### Option 2: Deploying with **Firebase Hosting**

1. **Install Firebase CLI**:
   Install Firebase CLI using npm:
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Firebase**:
   Navigate to your Flutter project and initialize Firebase hosting:
   ```bash
   firebase init
   ```
   During the setup:
   - Choose **Hosting**.
   - Set the public directory to `build/web`.
   - Enable URL rewrites to `index.html` for all routes (critical for Flutter apps).

3. **Deploy the App**:
   Use this command to deploy the app:
   ```bash
   firebase deploy
   ```

4. **Check the Deployment**:
   Visit the URL provided by Firebase to confirm that your Flutter app is live.

---

### 2. **Domain Setup**:
   If you have a custom domain, configure your DNS settings to point to your server or Firebase Hosting.

---

### 3. **Debugging Common Issues**:
   If you encounter errors, check the relevant logs:
   - For Nginx:
     ```bash
     sudo tail -f /var/log/nginx/error.log
     ```
   - For Firebase: Use browser developer tools and the Firebase console for detailed logs.

By following these steps, you should be able to deploy your **Flutter web app** successfully. If you face any specific issues, feel free to reach out for more detailed troubleshooting!