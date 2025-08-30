#!/bin/bash

# Create CIDR Calculator Flask Project
echo "🚀 Setting up CIDR Calculator Flask Application..."

# Create project directory
mkdir -p cidr_calculator
cd cidr_calculator

# Create Flask app structure
mkdir -p templates static/css static/js

# Create requirements.txt
cat > requirements.txt << 'EOF'
Flask==2.3.3
ipaddress
gunicorn==21.2.0
EOF

# Create the main Flask app (app.py)
cat > app.py << 'EOF'
from flask import Flask, render_template, jsonify, request
import ipaddress
import json

app = Flask(__name__)

class CIDRCalculator:
    def __init__(self, cidr_input):
        try:
            self.network = ipaddress.IPv4Network(cidr_input, strict=False)
            self.is_valid = True
        except:
            self.is_valid = False
            self.network = None
    
    def get_calculations(self):
        if not self.is_valid:
            return None
        
        # Get network details
        network_address = self.network.network_address
        broadcast_address = self.network.broadcast_address
        netmask = self.network.netmask
        prefix_len = self.network.prefixlen
        
        # Get usable host range
        hosts = list(self.network.hosts())
        first_usable = hosts[0] if hosts else network_address
        last_usable = hosts[-1] if hosts else network_address
        
        # Convert IP to binary
        def ip_to_binary(ip):
            octets = str(ip).split('.')
            binary = ''
            for octet in octets:
                binary += format(int(octet), '08b')
            return binary
        
        # Get binary representation
        ip_binary = ip_to_binary(network_address)
        
        return {
            'network_ip': str(network_address),
            'broadcast_ip': str(broadcast_address),
            'netmask': str(netmask),
            'prefix_length': prefix_len,
            'total_hosts': self.network.num_addresses,
            'usable_hosts': len(hosts),
            'first_usable': str(first_usable),
            'last_usable': str(last_usable),
            'binary': ip_binary,
            'octets': str(network_address).split('.'),
            'is_private': self.network.is_private
        }

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/calculate', methods=['POST'])
def calculate():
    data = request.get_json()
    cidr_input = data.get('cidr', '192.168.1.0/24')
    
    calculator = CIDRCalculator(cidr_input)
    result = calculator.get_calculations()
    
    if result:
        return jsonify({'success': True, 'data': result})
    else:
        return jsonify({'success': False, 'error': 'Invalid CIDR notation'})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
EOF

# Create the HTML template
cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Interactive Visual CIDR Calculator</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.2/gsap.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
            overflow-x: hidden;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }

        .header {
            text-align: center;
            margin-bottom: 40px;
            animation: fadeInDown 1s ease-out;
        }

        .header h1 {
            font-size: 3.5rem;
            font-weight: 800;
            color: white;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }

        .header p {
            font-size: 1.2rem;
            color: rgba(255,255,255,0.9);
            margin-bottom: 30px;
        }

        .calculator-card {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1);
            transform: translateY(20px);
            opacity: 0;
            animation: slideInUp 1s ease-out 0.3s forwards;
        }

        .input-section {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 20px;
            margin-bottom: 40px;
            flex-wrap: wrap;
        }

        .octet-input {
            position: relative;
        }

        .octet-input input {
            width: 80px;
            height: 80px;
            font-size: 2rem;
            text-align: center;
            border: 3px solid #e0e0e0;
            border-radius: 15px;
            outline: none;
            transition: all 0.3s ease;
            font-weight: 600;
        }

        .octet-input input:focus {
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.2);
            transform: scale(1.05);
        }

        .octet-1 { background: linear-gradient(135deg, #ff6b6b, #ff8e8e); }
        .octet-2 { background: linear-gradient(135deg, #4ecdc4, #7bdad6); }
        .octet-3 { background: linear-gradient(135deg, #45b7d1, #96c7ed); }
        .octet-4 { background: linear-gradient(135deg, #f9ca24, #fce473); }
        .prefix { background: linear-gradient(135deg, #6c5ce7, #a29bfe); }

        .separator {
            font-size: 3rem;
            font-weight: bold;
            color: #667eea;
        }

        .binary-display {
            margin: 30px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 15px;
            border: 2px dashed #667eea;
            opacity: 0;
            transform: translateY(20px);
            transition: all 0.5s ease;
        }

        .binary-display.show {
            opacity: 1;
            transform: translateY(0);
        }

        .binary-row {
            display: flex;
            justify-content: center;
            gap: 10px;
            flex-wrap: wrap;
            margin: 10px 0;
        }

        .binary-group {
            display: flex;
            gap: 2px;
            padding: 5px;
            border-radius: 8px;
            position: relative;
        }

        .binary-bit {
            width: 35px;
            height: 35px;
            border: 2px solid #333;
            display: flex;
            align-items: center;
            justify-content: center;
            font-family: 'Courier New', monospace;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s ease;
        }

        .binary-bit:hover {
            transform: scale(1.1);
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        }

        .results-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 25px;
            margin-top: 30px;
            opacity: 0;
            transform: translateY(20px);
            transition: all 0.5s ease;
        }

        .results-grid.show {
            opacity: 1;
            transform: translateY(0);
        }

        .result-card {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 25px;
            border-radius: 15px;
            text-align: center;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            transform: scale(0.9);
            animation: popIn 0.6s ease-out forwards;
        }

        .result-card h3 {
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
            opacity: 0.9;
        }

        .result-card .value {
            font-size: 1.8rem;
            font-weight: 700;
            font-family: 'Courier New', monospace;
        }

        .action-buttons {
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-top: 30px;
            flex-wrap: wrap;
        }

        .btn {
            padding: 15px 30px;
            border: none;
            border-radius: 50px;
            font-size: 1.1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 10px;
        }

        .btn-primary {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
        }

        .btn-secondary {
            background: linear-gradient(135deg, #ffeaa7, #fdcb6e);
            color: #333;
        }

        .btn:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.2);
        }

        .particles-container {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            pointer-events: none;
            z-index: -1;
        }

        @keyframes fadeInDown {
            from { opacity: 0; transform: translateY(-30px); }
            to { opacity: 1; transform: translateY(0); }
        }

        @keyframes slideInUp {
            from { opacity: 0; transform: translateY(30px); }
            to { opacity: 1; transform: translateY(0); }
        }

        @keyframes popIn {
            from { transform: scale(0.8); opacity: 0; }
            to { transform: scale(1); opacity: 1; }
        }

        .loading-spinner {
            display: none;
            width: 40px;
            height: 40px;
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 0 auto;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        .error-message {
            color: #e74c3c;
            text-align: center;
            padding: 15px;
            background: rgba(231, 76, 60, 0.1);
            border-radius: 10px;
            margin: 20px 0;
            display: none;
        }

        @media (max-width: 768px) {
            .header h1 { font-size: 2.5rem; }
            .calculator-card { padding: 20px; }
            .octet-input input { width: 60px; height: 60px; font-size: 1.5rem; }
            .separator { font-size: 2rem; }
        }
    </style>
</head>
<body>
    <div class="particles-container" id="particles"></div>
    
    <div class="container">
        <div class="header">
            <h1>🌐 CIDR Calculator</h1>
            <p>Interactive Visual Network Range Calculator with Real-time Binary Visualization</p>
        </div>

        <div class="calculator-card">
            <div class="input-section">
                <div class="octet-input">
                    <input type="number" class="octet-1" id="octet1" min="0" max="255" value="192" placeholder="192">
                </div>
                <span class="separator">.</span>
                
                <div class="octet-input">
                    <input type="number" class="octet-2" id="octet2" min="0" max="255" value="168" placeholder="168">
                </div>
                <span class="separator">.</span>
                
                <div class="octet-input">
                    <input type="number" class="octet-3" id="octet3" min="0" max="255" value="1" placeholder="1">
                </div>
                <span class="separator">.</span>
                
                <div class="octet-input">
                    <input type="number" class="octet-4" id="octet4" min="0" max="255" value="0" placeholder="0">
                </div>
                <span class="separator">/</span>
                
                <div class="octet-input">
                    <input type="number" class="prefix" id="prefix" min="0" max="32" value="24" placeholder="24">
                </div>
            </div>

            <div class="action-buttons">
                <button class="btn btn-primary" onclick="calculateCIDR()">
                    🚀 Calculate CIDR
                </button>
                <button class="btn btn-secondary" onclick="randomizeIP()">
                    🎲 Random IP
                </button>
            </div>

            <div class="loading-spinner" id="loading"></div>
            <div class="error-message" id="error"></div>

            <div class="binary-display" id="binaryDisplay">
                <h3 style="text-align: center; margin-bottom: 20px; color: #667eea;">Binary Representation</h3>
                <div class="binary-row" id="binaryRow"></div>
            </div>

            <div class="results-grid" id="resultsGrid"></div>
        </div>
    </div>

    <script>
        // Particle animation setup
        function initParticles() {
            const scene = new THREE.Scene();
            const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
            const renderer = new THREE.WebGLRenderer({ alpha: true });
            
            renderer.setSize(window.innerWidth, window.innerHeight);
            renderer.setClearColor(0x000000, 0);
            document.getElementById('particles').appendChild(renderer.domElement);

            // Create particles
            const particleGeometry = new THREE.BufferGeometry();
            const particleCount = 100;
            const posArray = new Float32Array(particleCount * 3);

            for(let i = 0; i < particleCount * 3; i++) {
                posArray[i] = (Math.random() - 0.5) * 10;
            }

            particleGeometry.setAttribute('position', new THREE.BufferAttribute(posArray, 3));

            const particleMaterial = new THREE.PointsMaterial({
                size: 0.02,
                color: 0xffffff,
                transparent: true,
                opacity: 0.3
            });

            const particleSystem = new THREE.Points(particleGeometry, particleMaterial);
            scene.add(particleSystem);

            camera.position.z = 3;

            function animateParticles() {
                requestAnimationFrame(animateParticles);
                
                particleSystem.rotation.x += 0.001;
                particleSystem.rotation.y += 0.001;
                
                renderer.render(scene, camera);
            }
            
            animateParticles();

            // Handle window resize
            window.addEventListener('resize', () => {
                camera.aspect = window.innerWidth / window.innerHeight;
                camera.updateProjectionMatrix();
                renderer.setSize(window.innerWidth, window.innerHeight);
            });
        }

        // Auto-calculate on input change
        document.addEventListener('DOMContentLoaded', function() {
            initParticles();
            calculateCIDR(); // Initial calculation
            
            // Add event listeners to all inputs
            ['octet1', 'octet2', 'octet3', 'octet4', 'prefix'].forEach(id => {
                document.getElementById(id).addEventListener('input', debounce(calculateCIDR, 500));
            });
        });

        function debounce(func, wait) {
            let timeout;
            return function executedFunction(...args) {
                const later = () => {
                    clearTimeout(timeout);
                    func(...args);
                };
                clearTimeout(timeout);
                timeout = setTimeout(later, wait);
            };
        }

        function validateInputs() {
            const octet1 = parseInt(document.getElementById('octet1').value) || 0;
            const octet2 = parseInt(document.getElementById('octet2').value) || 0;
            const octet3 = parseInt(document.getElementById('octet3').value) || 0;
            const octet4 = parseInt(document.getElementById('octet4').value) || 0;
            const prefix = parseInt(document.getElementById('prefix').value) || 0;

            if (octet1 > 255 || octet2 > 255 || octet3 > 255 || octet4 > 255) {
                showError('Octets must be between 0-255');
                return false;
            }
            if (prefix > 32) {
                showError('Prefix must be between 0-32');
                return false;
            }
            
            hideError();
            return true;
        }

        function showError(message) {
            const errorDiv = document.getElementById('error');
            errorDiv.textContent = message;
            errorDiv.style.display = 'block';
            gsap.fromTo(errorDiv, {opacity: 0, y: -20}, {opacity: 1, y: 0, duration: 0.3});
        }

        function hideError() {
            document.getElementById('error').style.display = 'none';
        }

        async function calculateCIDR() {
            if (!validateInputs()) return;

            const loading = document.getElementById('loading');
            loading.style.display = 'block';

            const cidr = `${document.getElementById('octet1').value}.${document.getElementById('octet2').value}.${document.getElementById('octet3').value}.${document.getElementById('octet4').value}/${document.getElementById('prefix').value}`;

            try {
                const response = await fetch('/calculate', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ cidr: cidr })
                });

                const result = await response.json();
                loading.style.display = 'none';

                if (result.success) {
                    displayResults(result.data);
                    displayBinary(result.data);
                } else {
                    showError(result.error || 'Invalid CIDR notation');
                }
            } catch (error) {
                loading.style.display = 'none';
                showError('Error calculating CIDR. Please try again.');
                console.error('Error:', error);
            }
        }

        function displayBinary(data) {
            const binaryDisplay = document.getElementById('binaryDisplay');
            const binaryRow = document.getElementById('binaryRow');
            
            // Clear previous content
            binaryRow.innerHTML = '';
            
            const binary = data.binary;
            const colors = ['#ff6b6b', '#4ecdc4', '#45b7d1', '#f9ca24'];
            
            for (let i = 0; i < 4; i++) {
                const group = document.createElement('div');
                group.className = 'binary-group';
                group.style.backgroundColor = colors[i] + '20';
                group.style.border = `2px solid ${colors[i]}`;
                
                for (let j = 0; j < 8; j++) {
                    const bit = document.createElement('div');
                    bit.className = 'binary-bit';
                    bit.style.backgroundColor = colors[i];
                    bit.style.color = 'white';
                    bit.textContent = binary[i * 8 + j];
                    
                    // Add click animation
                    bit.addEventListener('click', function() {
                        gsap.to(bit, {
                            scale: 1.3,
                            duration: 0.1,
                            yoyo: true,
                            repeat: 1,
                            ease: "power2.out"
                        });
                    });
                    
                    group.appendChild(bit);
                }
                
                binaryRow.appendChild(group);
            }
            
            // Animate binary display
            gsap.fromTo(binaryDisplay, 
                {opacity: 0, y: 20}, 
                {opacity: 1, y: 0, duration: 0.5, delay: 0.2}
            );
            binaryDisplay.classList.add('show');
        }

        function displayResults(data) {
            const resultsGrid = document.getElementById('resultsGrid');
            
            const results = [
                { label: 'Network IP', value: data.network_ip, icon: '🌐' },
                { label: 'Broadcast IP', value: data.broadcast_ip, icon: '📡' },
                { label: 'Netmask', value: data.netmask, icon: '🎭' },
                { label: 'Total Hosts', value: data.total_hosts.toLocaleString(), icon: '💻' },
                { label: 'Usable Hosts', value: data.usable_hosts.toLocaleString(), icon: '✅' },
                { label: 'First Usable', value: data.first_usable, icon: '🟢' },
                { label: 'Last Usable', value: data.last_usable, icon: '🔴' },
                { label: 'Network Type', value: data.is_private ? 'Private' : 'Public', icon: '🔒' }
            ];

            resultsGrid.innerHTML = '';
            
            results.forEach((result, index) => {
                const card = document.createElement('div');
                card.className = 'result-card';
                card.innerHTML = `
                    <h3>${result.icon} ${result.label}</h3>
                    <div class="value">${result.value}</div>
                `;
                
                // Add stagger animation
                gsap.fromTo(card, 
                    {opacity: 0, y: 30, scale: 0.8}, 
                    {opacity: 1, y: 0, scale: 1, duration: 0.5, delay: index * 0.1, ease: "back.out(1.7)"}
                );
                
                resultsGrid.appendChild(card);
            });
            
            resultsGrid.classList.add('show');
        }

        function randomizeIP() {
            // Generate random private IP ranges
            const privateRanges = [
                ['10', '0', '0', '0'],
                ['172', '16', '0', '0'],
                ['192', '168', '1', '0']
            ];
            
            const randomRange = privateRanges[Math.floor(Math.random() * privateRanges.length)];
            const randomOctets = [
                randomRange[0],
                randomRange[1],
                Math.floor(Math.random() * 256).toString(),
                Math.floor(Math.random() * 256).toString()
            ];
            const randomPrefix = Math.floor(Math.random() * 17) + 16; // 16-32
            
            // Animate input changes
            ['octet1', 'octet2', 'octet3', 'octet4'].forEach((id, index) => {
                const input = document.getElementById(id);
                gsap.to(input, {
                    scale: 1.1,
                    duration: 0.1,
                    yoyo: true,
                    repeat: 1,
                    onComplete: () => {
                        input.value = randomOctets[index];
                    }
                });
            });
            
            const prefixInput = document.getElementById('prefix');
            gsap.to(prefixInput, {
                scale: 1.1,
                duration: 0.1,
                yoyo: true,
                repeat: 1,
                onComplete: () => {
                    prefixInput.value = randomPrefix;
                    setTimeout(calculateCIDR, 300);
                }
            });
        }

        // Copy functionality
        function copyToClipboard(text) {
            navigator.clipboard.writeText(text).then(() => {
                // Show success message
                const notification = document.createElement('div');
                notification.textContent = 'Copied to clipboard!';
                notification.style.cssText = `
                    position: fixed;
                    top: 20px;
                    right: 20px;
                    background: #4CAF50;
                    color: white;
                    padding: 15px 20px;
                    border-radius: 10px;
                    z-index: 1000;
                    font-weight: bold;
                `;
                document.body.appendChild(notification);
                
                gsap.fromTo(notification, 
                    {opacity: 0, x: 100}, 
                    {opacity: 1, x: 0, duration: 0.3}
                );
                
                setTimeout(() => {
                    gsap.to(notification, {
                        opacity: 0,
                        x: 100,
                        duration: 0.3,
                        onComplete: () => document.body.removeChild(notification)
                    });
                }, 2000);
            });
        }
    </script>
</body>
</html>
EOF

# Create run script
cat > run.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting CIDR Calculator Application..."
echo "📦 Installing dependencies..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "🔧 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install requirements
echo "📦 Installing Python packages..."
pip install -r requirements.txt

# Run the application
echo "🌐 Starting Flask server..."
echo "📍 Open your browser and go to: http://localhost:5000"
echo "🛑 Press Ctrl+C to stop the server"
echo ""

python app.py
EOF

# Create Windows batch file
cat > run.bat << 'EOF'
@echo off
echo 🚀 Starting CIDR Calculator Application...
echo 📦 Installing dependencies...

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python is not installed. Please install Python first.
    pause
    exit /b 1
)

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo 🔧 Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
echo 🔧 Activating virtual environment...
call venv\Scripts\activate.bat

REM Install requirements
echo 📦 Installing Python packages...
pip install -r requirements.txt

REM Run the application
echo 🌐 Starting Flask server...
echo 📍 Open your browser and go to: http://localhost:5000
echo 🛑 Press Ctrl+C to stop the server
echo.

python app.py
pause
EOF

# Create README
cat > README.md << 'EOF'
# 🌐 Interactive Visual CIDR Calculator

A modern, interactive CIDR calculator with beautiful animations and real-time binary visualization.

## ✨ Features

- **Interactive Input**: Color-coded IP octets with real-time validation
- **Binary Visualization**: Click-able binary representation of IP addresses
- **Animated Results**: Smooth animations powered by GSAP
- **3D Particles**: Background particle system using Three.js
- **Responsive Design**: Works perfectly on desktop and mobile
- **Real-time Calculations**: Auto-calculates as you type
- **Random IP Generator**: Generate random private IP ranges for testing

## 🚀 Quick Start

### For Linux/Mac:
```bash
chmod +x run.sh
./run.sh
```

### For Windows:
```bash
run.bat
```

### Manual Setup:
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
# On Linux/Mac:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the application
python app.py
```

## 📱 Usage

1. Open your browser and go to `http://localhost:5000`
2. Enter IP address octets in the colored input fields
3. Set the CIDR prefix (subnet mask bits)
4. Click "Calculate CIDR" or let it auto-calculate
5. View the results with beautiful animations
6. Click on binary bits for interactive feedback
7. Use "Random IP" button to generate test cases

## 🛠️ Technologies

- **Backend**: Python Flask
- **Frontend**: HTML5, CSS3, JavaScript
- **Animations**: GSAP (GreenSock)
- **3D Graphics**: Three.js
- **Styling**: Custom CSS with gradients and animations
- **Responsive**: Mobile-first design

## 📊 What It Calculates

- Network IP address
- Broadcast IP address
- Subnet mask (netmask)
- Total number of hosts
- Usable host count
- First usable IP
- Last usable IP
- Binary representation
- Private/Public network classification

## 🎨 Design Features

- Gradient backgrounds
- Glassmorphism effects
- Smooth transitions
- Interactive hover effects
- Color-coded IP octets
- Animated loading states
- Error handling with animations
- Responsive grid layouts

## 📝 Requirements

- Python 3.7+
- Modern web browser
- Internet connection (for CDN resources)

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is open source and available under the MIT License.
EOF

# Make run script executable
chmod +x run.sh

echo "✅ CIDR Calculator project created successfully!"
echo ""
echo "📁 Project structure:"
echo "   cidr_calculator/"
echo "   ├── app.py              (Flask application)"
echo "   ├── requirements.txt    (Python dependencies)"
echo "   ├── templates/"
echo "   │   └── index.html     (Main HTML template)"
echo "   ├── run.sh             (Linux/Mac startup script)"
echo "   ├── run.bat            (Windows startup script)"
echo "   └── README.md          (Documentation)"
echo ""
echo "🚀 To run the application:"
echo "   Linux/Mac: ./run.sh"
echo "   Windows: run.bat"
echo ""
echo "🌐 The app will be available at: http://localhost:5000"