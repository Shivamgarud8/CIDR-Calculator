CIDR Calculator
A simple CIDR (Classless Inter-Domain Routing) calculator built with Python Flask. This lightweight application calculates network information from CIDR notation in a single Python file.



Installation
1. Clone the Repository
git clone <your-repository-url>
cd cidr-calculator


2. Create a Virtual Environment (Recommended)
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate

# On macOS/Linux:
source venv/bin/activate

3. Install Dependencies
pip install -r requirements.txt

4. Create requirements.txt
Flask==2.3.3


Running the Application
Development Mode
python app.py


Production Mode
For production deployment, you can run the application on port 5000 and expose it:
Run on all interfaces, port 5000
python app.py --host=0.0.0.0 --port=5000
Or modify your app.py to include:
pythonif __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)



else ..
chmod +x full_setup.sh
./full_setup.sh
its should run 
