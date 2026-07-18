const express = require('express');
const cors = require('cors');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;

// Configuration
const SECRET_SALT = 'local_secret_rosava_123';
const LINKVERTISE_URL = 'https://linkvertise.com/placeholder'; // Replace with actual Linkvertise gate URL

app.use(cors());
app.use(express.json());

// Helper function to generate dynamic daily keys based on Date
function getDailyKey(offset = 0) {
    const d = new Date();
    d.setDate(d.getDate() + offset);
    
    // Format as YYYY-MM-DD
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const dateStr = `${year}-${month}-${day}`;
    
    // Create MD5 hash
    const hash = crypto.createHash('md5').update(dateStr + SECRET_SALT).digest('hex').toUpperCase();
    
    // Format: DAMI-XXXX-XXXX-XXXX
    return `DAMI-${hash.substring(0, 4)}-${hash.substring(4, 8)}-${hash.substring(8, 12)}`;
}

// ----------------------------------------------------------------------------
// SVG ASSETS (HANDCRAFTED DESIGN MODULES)
// ----------------------------------------------------------------------------
const SVG_ROSE = `
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
    <path d="M50 20C40 20 30 28 30 40C30 55 45 68 50 72C55 68 70 55 70 40C70 28 60 20 50 20Z" fill="url(#roseGrad)" />
    <path d="M50 30C45 30 40 34 40 40C40 46 45 50 50 52C55 50 60 46 60 40C60 34 55 30 50 30Z" fill="#ff7da0" opacity="0.8"/>
    <path d="M50 70V90" stroke="#3b8b5c" stroke-width="4" stroke-linecap="round"/>
    <path d="M50 80C42 80 35 76 35 76" stroke="#3b8b5c" stroke-width="3" stroke-linecap="round"/>
    <path d="M50 85C58 85 65 81 65 81" stroke="#3b8b5c" stroke-width="3" stroke-linecap="round"/>
    <defs>
        <linearGradient id="roseGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#983c50" />
            <stop offset="100%" stop-color="#e65c7b" />
        </linearGradient>
    </defs>
</svg>
`;

const SVG_LINKVERTISE = `
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
    <circle cx="50" cy="50" r="48" fill="url(#lvGrad)"/>
    <path d="M55 22L30 54h18L44 78l26-32H52z" fill="#ffffff" />
    <defs>
        <linearGradient id="lvGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#ff5722" />
            <stop offset="100%" stop-color="#ffb74d" />
        </linearGradient>
    </defs>
</svg>
`;

// ----------------------------------------------------------------------------
// ROUTE 1: Main Gateway Page (dami.lol index)
// ----------------------------------------------------------------------------
app.get('/', (req, res) => {
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dami - Key System Hub</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: 'Outfit', sans-serif;
            background-color: #140f12;
            color: #f5e6eb;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            overflow: hidden;
            position: relative;
        }

        .bg-pattern {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            opacity: 0.05;
            background-image: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23983C50" width="80" height="80"><path d="M12 2C11.5 2 10 3.5 10 5.5C10 7.5 11.5 9 12 9C12.5 9 14 7.5 14 5.5C14 3.5 12.5 2 12 2ZM12 9C10.5 9 8 10.5 8 13C8 15.5 10.5 17 12 17C13.5 17 16 15.5 16 13C16 10.5 13.5 9 12 9ZM12 17C9 17 6 18.5 6 21C6 21.5 6.5 22 7 22H17C17.5 22 18 21.5 18 21C18 18.5 15 17 12 17Z"/></svg>');
            background-repeat: repeat;
            pointer-events: none;
        }

        .card {
            background: #2a2027;
            border: 1px solid #44303c;
            padding: 32px 30px;
            border-radius: 12px;
            width: 95%;
            max-width: 400px;
            text-align: center;
            box-shadow: 0 20px 45px rgba(0, 0, 0, 0.7);
            animation: scaleIn 0.4s ease;
            position: relative;
            z-index: 10;
        }

        @keyframes scaleIn {
            from { opacity: 0; transform: scale(0.96); }
            to { opacity: 1; transform: scale(1); }
        }

        .brand-header {
            display: flex;
            flex-direction: column;
            align-items: center;
            margin-bottom: 24px;
        }

        .logo-wrapper {
            width: 72px;
            height: 72px;
            margin-bottom: 12px;
        }

        .logo-wrapper svg {
            width: 100%;
            height: 100%;
        }

        h1 {
            font-size: 24px;
            font-weight: 700;
            color: #ffffff;
            letter-spacing: 1.5px;
        }

        .domain {
            font-size: 13px;
            font-weight: 500;
            color: #e65c7b;
            margin-top: 2px;
        }

        .description {
            font-size: 12px;
            color: #b496a0;
            line-height: 1.6;
            margin-bottom: 26px;
            text-align: left;
            background: rgba(30, 24, 28, 0.5);
            padding: 14px;
            border-radius: 8px;
            border: 1px solid #3d2a36;
        }

        .step-title {
            font-weight: 600;
            color: #f5e6eb;
            margin-bottom: 4px;
        }

        /* Large Linkvertise Interactive Button */
        .lv-btn {
            background: #1e181c;
            border: 1px solid #ff5722;
            color: #ffffff;
            font-size: 13px;
            font-weight: 600;
            width: 100%;
            padding: 14px;
            border-radius: 8px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            transition: all 0.25s ease;
            box-shadow: 0 0 15px rgba(255, 87, 34, 0.15);
        }

        .lv-btn:hover {
            background: #ff5722;
            box-shadow: 0 0 25px rgba(255, 87, 34, 0.4);
            transform: translateY(-2px);
        }

        .lv-btn-icon {
            width: 22px;
            height: 22px;
            flex-shrink: 0;
        }

        .footer-note {
            font-size: 10px;
            color: #8c737d;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="bg-pattern"></div>
    <div class="card">
        <div class="brand-header">
            <div class="logo-wrapper">
                ${SVG_ROSE}
            </div>
            <h1>DAMI KEY SYSTEM</h1>
            <div class="domain">dami.lol</div>
        </div>

        <div class="description">
            <div style="margin-bottom: 12px;">
                <div class="step-title">1. Linkvertise Checkpoint</div>
                Complete the quick ad tasks on Linkvertise to verify your access.
            </div>
            <div>
                <div class="step-title">2. Get Key</div>
                After verification, you will be redirected back to claim your key valid for 24 hours.
            </div>
        </div>

        <button class="lv-btn" onclick="window.location.href='/getkey'">
            <div class="lv-btn-icon">${SVG_LINKVERTISE}</div>
            Proceed via Linkvertise
        </button>

        <p class="footer-note">Secure daily verification gateway &copy; dami.lol</p>
    </div>
</body>
</html>
    `);
});

// ----------------------------------------------------------------------------
// ROUTE 2: Target key landing page (redirect target from Linkvertise)
// ----------------------------------------------------------------------------
app.get('/key', (req, res) => {
    const todayKey = getDailyKey(0);
    
    res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dami - Key Gateway</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body {
            font-family: 'Outfit', sans-serif;
            background-color: #140f12;
            color: #f5e6eb;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            overflow: hidden;
            position: relative;
        }

        .bg-pattern {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            opacity: 0.05;
            background-image: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="%23983C50" width="80" height="80"><path d="M12 2C11.5 2 10 3.5 10 5.5C10 7.5 11.5 9 12 9C12.5 9 14 7.5 14 5.5C14 3.5 12.5 2 12 2ZM12 9C10.5 9 8 10.5 8 13C8 15.5 10.5 17 12 17C13.5 17 16 15.5 16 13C16 10.5 13.5 9 12 9ZM12 17C9 17 6 18.5 6 21C6 21.5 6.5 22 7 22H17C17.5 22 18 21.5 18 21C18 18.5 15 17 12 17Z"/></svg>');
            background-repeat: repeat;
            pointer-events: none;
        }

        .card {
            background: #2a2027;
            border: 1px solid #44303c;
            padding: 28px 30px;
            border-radius: 12px;
            width: 90%;
            max-width: 380px;
            text-align: center;
            box-shadow: 0 15px 35px rgba(0, 0, 0, 0.6);
            animation: fadeIn 0.5s ease;
            position: relative;
            z-index: 10;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: scale(0.95); }
            to { opacity: 1; transform: scale(1); }
        }

        .welcome-text {
            font-size: 11px;
            color: #b496a0;
            margin-bottom: 2px;
            letter-spacing: 0.5px;
        }

        .brand-text {
            font-size: 22px;
            font-weight: 700;
            color: #e65c7b;
            margin-bottom: 24px;
            letter-spacing: 2px;
        }

        .key-input-wrapper {
            background: #1e181c;
            border: 1px solid #44303c;
            border-radius: 6px;
            padding: 8px 12px;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            height: 36px;
            transition: border-color 0.2s ease;
        }

        .key-input-wrapper:hover {
            border-color: #983c50;
        }

        .shield-icon {
            width: 16px;
            height: 16px;
            margin-right: 10px;
            fill: #b496a0;
            flex-shrink: 0;
        }

        .key-text {
            font-size: 11px;
            font-family: monospace;
            font-weight: bold;
            color: #f5e6eb;
            letter-spacing: 1.5px;
            user-select: all;
            flex-grow: 1;
            text-align: left;
        }

        .button-group {
            display: flex;
            justify-content: space-between;
            gap: 10px;
            margin-bottom: 20px;
        }

        .btn {
            background: #1e181c;
            border: 1px solid #44303c;
            color: #f5e6eb;
            font-size: 11px;
            font-weight: 500;
            padding: 8px 10px;
            border-radius: 6px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 6px;
            transition: all 0.2s ease;
            height: 32px;
        }

        .btn-exit {
            width: 28%;
        }

        .btn-copy {
            width: 38%;
        }

        .btn-discord {
            width: 28%;
        }

        .btn:hover {
            border-color: #983c50;
            background: #2a2027;
            transform: translateY(-1px);
        }

        .btn-icon {
            width: 12px;
            height: 12px;
            fill: #f5e6eb;
        }

        .status-text {
            font-size: 10px;
            color: #b496a0;
            line-height: 1.5;
        }

        .toast {
            position: absolute;
            bottom: 30px;
            left: 50%;
            transform: translateX(-50%) translateY(100px);
            background: #983c50;
            color: white;
            padding: 10px 20px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 500;
            box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);
            transition: transform 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            z-index: 100;
        }

        .toast.show {
            transform: translateX(-50%) translateY(0);
        }
    </style>
</head>
<body>
    <div class="bg-pattern"></div>
    <div class="card">
        <div class="welcome-text">Your generated key for</div>
        <div class="brand-text">DAMI.LOL</div>
        
        <div class="key-input-wrapper">
            <svg class="shield-icon" viewBox="0 0 24 24">
                <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 10.99h7c-.53 4.12-3.28 7.79-7 8.94V12H5V6.3l7-3.11v8.8z"/>
            </svg>
            <div class="key-text" id="keyText">${todayKey}</div>
        </div>

        <div class="button-group">
            <button class="btn btn-exit" id="exitBtn" title="Close Page">
                <svg class="btn-icon" viewBox="0 0 24 24">
                    <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41Z"/>
                </svg>
                Exit
            </button>
            <button class="btn btn-copy" id="copyBtn" title="Copy Key">
                <svg class="btn-icon" viewBox="0 0 24 24">
                    <path d="M16 1H4C2.9 1 2 1.9 2 3V17H4V3H16V1ZM19 5H8C6.9 5 6 5.9 6 7V21C6 22.1 6.9 23 8 23H19C20.1 23 21 22.1 21 21V7C21 5.9 20.1 5 19 5ZM19 21H8V7H19V21Z"/>
                </svg>
                Copy Key
            </button>
            <button class="btn btn-discord" id="discordBtn" title="Discord invite">
                <svg class="btn-icon" viewBox="0 0 24 24">
                    <path d="M12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12C22 6.48 17.52 2 12 2ZM12 6C13.66 6 15 7.34 15 9C15 10.66 13.66 12 12 12C10.34 12 9 10.66 9 9C9 7.34 10.34 6 12 6ZM12 18C9.58 18 7.48 16.52 6.54 14.4C6.51 14.34 6.54 14.28 6.6 14.24C7.74 13.62 9.08 13.26 10.5 13.26C10.6 13.26 10.7 13.26 10.8 13.26C11.18 13.88 11.84 14.3 12.6 14.3C13.36 14.3 14.02 13.88 14.4 13.26C14.5 13.26 14.6 13.26 14.7 13.26C16.12 13.26 17.46 13.62 18.6 14.24C18.66 14.28 18.69 14.34 18.66 14.4C17.72 16.52 15.62 18 12 18Z"/>
                </svg>
                Discord
            </button>
        </div>

        <p class="status-text">
            Copy the key above and paste it into the script UI popup in Roblox to unlock features. This key will expire at midnight.
        </p>
    </div>

    <div class="toast" id="toast">Key copied to clipboard!</div>

    <script>
        const keyText = document.getElementById('keyText').innerText;
        const copyBtn = document.getElementById('copyBtn');
        const exitBtn = document.getElementById('exitBtn');
        const discordBtn = document.getElementById('discordBtn');
        const toast = document.getElementById('toast');

        copyBtn.addEventListener('click', () => {
            navigator.clipboard.writeText(keyText).then(() => {
                showToast("Key copied to clipboard!");
            });
        });

        exitBtn.addEventListener('click', () => {
            window.close();
            setTimeout(() => {
                window.location.href = "https://www.google.com";
            }, 300);
        });

        discordBtn.addEventListener('click', () => {
            navigator.clipboard.writeText("https://discord.gg/m6YTVkRZ34").then(() => {
                showToast("Discord link copied to clipboard!");
            });
        });

        function showToast(message) {
            toast.innerText = message;
            toast.classList.add('show');
            setTimeout(() => {
                toast.classList.remove('show');
            }, 2500);
        }
    </script>
</body>
</html>
    `);
});

// Verification API called by Roblox Script
app.get('/api/verify', (req, res) => {
    const { key } = req.query;
    if (!key) {
        return res.status(400).json({ error: 'Key query parameter required' });
    }

    const todayKey = getDailyKey(0);
    const yesterdayKey = getDailyKey(-1);
    const tomorrowKey = getDailyKey(1); // Allow timezone buffer

    if (key === todayKey || key === yesterdayKey || key === tomorrowKey) {
        return res.json({ valid: true });
    }

    return res.json({ valid: false });
});

// Start server
app.listen(PORT, () => {
    console.log(`Dami Key System server is running on http://localhost:${PORT}`);
});
