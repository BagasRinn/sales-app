import os
import sys
sys.path.insert(0, '.')
os.environ['PYTHONPATH'] = '.'

from dotenv import load_dotenv
load_dotenv()
from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv('DATABASE_URL', '')
if not DATABASE_URL:
    print('DATABASE_URL not set')
    sys.exit(1)
else:
    DATABASE_URL = DATABASE_URL.replace('postgresql://', 'postgresql+psycopg2://', 1)
    engine = create_engine(DATABASE_URL)
    with engine.connect() as conn:
        result = conn.execute(text("SELECT COUNT(*) FROM products WHERE nama_supplier IS NOT NULL AND nama_supplier != ''")).scalar()
        print(f'Products with supplier: {result}')

        result2 = conn.execute(text("SELECT DISTINCT nama_supplier FROM products WHERE nama_supplier IS NOT NULL AND nama_supplier != '' ORDER BY nama_supplier")).fetchall()
        print(f'Distinct suppliers: {[r[0] for r in result2]}')

        result3 = conn.execute(text('SELECT COUNT(*) FROM supplier_targets')).scalar()
        print(f'Supplier targets: {result3}')

        # Check what branches exist
        result4 = conn.execute(text("SELECT DISTINCT branch FROM products WHERE branch IS NOT NULL")).fetchall()
        print(f'Product branches: {[r[0] for r in result4]}')

        # Check supplier_targets
        result5 = conn.execute(text("SELECT branch, supplier_name, period FROM supplier_targets LIMIT 10")).fetchall()
        print(f'Supplier targets sample: {result5}')
