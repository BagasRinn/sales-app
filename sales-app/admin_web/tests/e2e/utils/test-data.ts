/**
 * Test credentials for each role.
 * These should be overridden via environment variables in CI.
 */
export const TEST_USERS = {
  admin: {
    username: process.env.E2E_ADMIN_USERNAME || 'admin',
    password: process.env.E2E_ADMIN_PASSWORD || 'admin123',
    role: 'ADMIN' as const,
  },
  supervisor: {
    username: process.env.E2E_SUPERVISOR_USERNAME || 'supervisor',
    password: process.env.E2E_SUPERVISOR_PASSWORD || 'super123',
    role: 'SUPERVISOR' as const,
  },
  manager: {
    username: process.env.E2E_MANAGER_USERNAME || 'manager',
    password: process.env.E2E_MANAGER_PASSWORD || 'mgr123',
    role: 'MANAGER' as const,
  },
  sales: {
    username: process.env.E2E_SALES_USERNAME || 'sales',
    password: process.env.E2E_SALES_PASSWORD || 'sales123',
    role: 'SALES' as const,
  },
};

/** Demo data for creating/editing records */
export const TEST_DATA = {
  customer: {
    kode: 'TEST001',
    namaToko: 'Toko Test E2E',
    alamat: 'Jl. Test E2E No. 1',
    kodeArea: 'AREA01',
  },
  product: {
    sku: 'SKU-TEST-E2E',
    nama: 'Produk Test E2E',
    kategori: 'Makanan',
    satuan: 'PCS',
    harga: 15000,
  },
  supplier: {
    name: 'Supplier Test E2E',
    orderType: 'REGULER' as const,
  },
  bulletin: {
    title: 'Bulletin Test E2E',
    description: 'Deskripsi bulletin untuk E2E test',
  },
  user: {
    username: 'testuser_e2e',
    password: 'test123456',
    nama: 'Test User E2E',
    role: 'SALES' as const,
  },
  orderRejectReason: 'Barang tidak sesuai spesifikasi',
};

/** Test file paths (relative to test root) */
export const TEST_FILES = {
  validProductImport: 'test-data/product-import-valid.xlsx',
  invalidProductImport: 'test-data/product-import-invalid.xlsx',
  validCustomerImport: 'test-data/customer-import-valid.xlsx',
};
