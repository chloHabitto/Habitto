# Deployment Guide for habitto.nl

This guide will help you connect your Squarespace domain (habitto.nl) to your Habitto website.

## 🚀 Quick Start Options

### Option 1: Netlify (Recommended - Easiest & Free)

**Step 1: Deploy to Netlify**
1. Go to [netlify.com](https://www.netlify.com) and sign up/login
2. Click "Add new site" → "Deploy manually"
3. Drag and drop your entire `website` folder onto Netlify
4. Your site will be live at a URL like `habitto-xyz123.netlify.app`

**Step 2: Connect Your Domain**
1. In Netlify dashboard, go to **Site settings** → **Domain management**
2. Click **Add custom domain**
3. Enter `habitto.nl` and `www.habitto.nl`
4. Netlify will show you DNS records to add

**Step 3: Update DNS in Squarespace**
1. Log into your Squarespace account
2. Go to **Settings** → **Domains** → **habitto.nl**
3. Click **DNS Settings**
4. Add these DNS records (Netlify will provide exact values):
   - **A Record**: `@` → Netlify's IP (usually `75.2.60.5`)
   - **CNAME Record**: `www` → `habitto-xyz123.netlify.app`
5. Wait 24-48 hours for DNS to propagate

**Step 4: Enable HTTPS**
- Netlify automatically provides free SSL certificates
- Once DNS propagates, HTTPS will be enabled automatically

---

### Option 2: Vercel (Also Great & Free)

**Step 1: Deploy to Vercel**
1. Go to [vercel.com](https://www.vercel.com) and sign up/login
2. Click "Add New Project"
3. Import your `website` folder (or connect GitHub)
4. Your site will be live at `habitto-xyz123.vercel.app`

**Step 2: Connect Your Domain**
1. Go to **Project Settings** → **Domains**
2. Add `habitto.nl` and `www.habitto.nl`
3. Vercel will show DNS records to add

**Step 3: Update DNS in Squarespace**
- Follow the same DNS steps as Netlify above
- Use Vercel's provided DNS records instead

---

### Option 3: GitHub Pages (Free, but requires GitHub)

**Step 1: Create GitHub Repository**
```bash
cd website
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/habitto-website.git
git push -u origin main
```

**Step 2: Enable GitHub Pages**
1. Go to repository **Settings** → **Pages**
2. Select `main` branch and `/` (root) folder
3. Your site will be at `YOUR_USERNAME.github.io/habitto-website`

**Step 3: Use Custom Domain**
1. In Pages settings, add `habitto.nl` as custom domain
2. Add DNS records in Squarespace:
   - **A Records**: 
     - `185.199.108.153`
     - `185.199.109.153`
     - `185.199.110.153`
     - `185.199.111.153`
   - **CNAME Record**: `www` → `YOUR_USERNAME.github.io`

---

## 📋 Squarespace DNS Configuration

When connecting your domain, you'll need to add these DNS records in Squarespace:

### For Netlify:
```
Type    Name    Value
A       @       75.2.60.5
CNAME   www     your-site.netlify.app
```

### For Vercel:
```
Type    Name    Value
A       @       76.76.21.21
CNAME   www     cname.vercel-dns.com
```

### For GitHub Pages:
```
Type    Name    Value
A       @       185.199.108.153
A       @       185.199.109.153
A       @       185.199.110.153
A       @       185.199.111.153
CNAME   www     YOUR_USERNAME.github.io
```

## 🔧 Squarespace-Specific Steps

1. **Access DNS Settings:**
   - Log into Squarespace
   - Go to **Settings** → **Domains**
   - Click on **habitto.nl**
   - Click **DNS Settings**

2. **Remove Existing Records (if any):**
   - If Squarespace created default records, you may need to remove them
   - Keep only the records needed for your hosting service

3. **Add New Records:**
   - Click **Add Record**
   - Enter the type (A or CNAME)
   - Enter the host (@ for root, www for www subdomain)
   - Enter the value provided by your hosting service
   - Save

4. **Wait for Propagation:**
   - DNS changes can take 24-48 hours
   - Check status at [whatsmydns.net](https://www.whatsmydns.net)

## ✅ Verification

After DNS propagates, verify:
- ✅ `habitto.nl` loads your website
- ✅ `www.habitto.nl` redirects to `habitto.nl` (or loads the site)
- ✅ HTTPS is enabled (green lock icon)
- ✅ All pages load correctly

## 🆘 Troubleshooting

**Domain not working?**
- Wait 24-48 hours for DNS propagation
- Check DNS records are correct at [whatsmydns.net](https://www.whatsmydns.net)
- Verify records in Squarespace match hosting provider requirements

**HTTPS not working?**
- Most hosting services auto-enable HTTPS after DNS propagates
- Wait a few hours after DNS is correct
- Check hosting provider's SSL status

**Site not loading?**
- Clear browser cache
- Try incognito/private browsing
- Check hosting provider's status page

## 📝 Next Steps After Deployment

1. **Update App Store Links:**
   - Edit `index.html` and replace `#` with actual App Store links

2. **Add Analytics (Optional):**
   - Add Google Analytics or Plausible Analytics
   - Add tracking code to `index.html` before `</head>`

3. **Test Everything:**
   - Test on mobile devices
   - Test all links and buttons
   - Verify forms work (if you add any)

4. **SEO Optimization:**
   - Add Open Graph tags for social sharing
   - Submit sitemap to Google Search Console
   - Verify site in Google Search Console

## 🎉 You're Done!

Once DNS propagates, your website will be live at **habitto.nl**!

