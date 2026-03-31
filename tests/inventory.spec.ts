import { test, expect } from '@playwright/test';

test.describe('Inventory Tracker E2E', () => {
  test.describe.configure({ mode: 'serial' });

  test.beforeAll(async () => {
    // Optionally seed database, but UI tests flow sequentially
  });

  test('Positive: Add Product', async ({ page }) => {
    await page.goto('/');
    
    await page.getByRole('button', { name: 'Add Product' }).click();
    
    await page.locator('#name').fill('Test Product Alpha');
    await page.locator('#sku').fill('TSK-1234');
    await page.locator('#quantity').fill('50');
    
    await page.getByRole('button', { name: 'Save Product' }).click();
    
    await expect(page.locator('.product-item').filter({ hasText: 'Test Product Alpha' })).toBeVisible();
    await expect(page.locator('.product-item').filter({ hasText: 'TSK-1234' })).toBeVisible();
  });

  test('Negative: Duplicate SKU', async ({ page }) => {
    await page.goto('/');
    
    await page.getByRole('button', { name: 'Add Product' }).click();
    await page.locator('#name').fill('Test Product Beta');
    await page.locator('#sku').fill('TSK-1234'); // Intentional Duplicate
    await page.locator('#quantity').fill('10');
    
    await page.getByRole('button', { name: 'Save Product' }).click();
    
    await expect(page.getByText('A product with this SKU already exists.')).toBeVisible();
  });

  test('Negative: Empty Required Fields', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('button', { name: 'Add Product' }).click();
    
    await page.locator('#sku').fill('TSK-9999');
    
    await page.getByRole('button', { name: 'Save Product' }).click();
    
    // DOM HTML5 Validation
    const nameInput = page.locator('#name');
    const isValid = await nameInput.evaluate((el: HTMLInputElement) => el.checkValidity());
    expect(isValid).toBe(false);
  });

  test('Positive: Search Product', async ({ page }) => {
    await page.goto('/');
    
    await page.getByRole('button', { name: 'Add Product' }).click();
    await page.locator('#name').fill('Unique Hidden Item');
    await page.locator('#sku').fill('UHI-001');
    await page.locator('#quantity').fill('1');
    await page.getByRole('button', { name: 'Save Product' }).click();
    await expect(page.locator('.product-item').filter({ hasText: 'Unique Hidden Item' })).toBeVisible();

    const searchInput = page.locator('input[type="search"]');
    await searchInput.fill('TSK-1234');
    await page.getByRole('button', { name: 'Search' }).click();
    
    await expect(page.locator('.product-item').filter({ hasText: 'Test Product Alpha' })).toBeVisible();
    await expect(page.locator('.product-item').filter({ hasText: 'Unique Hidden Item' })).not.toBeVisible();
  });

  test('Negative: Empty Search Results', async ({ page }) => {
    await page.goto('/');
    const searchInput = page.locator('input[type="search"]');
    await searchInput.fill('XYZ-NONEXISTENT');
    await page.getByRole('button', { name: 'Search' }).click();
    
    await expect(page.getByText('No products found.')).toBeVisible();
  });

  test('Positive: Update Quantity', async ({ page }) => {
    await page.goto('/');
    const searchInput = page.locator('input[type="search"]');
    await searchInput.fill('');
    await page.getByRole('button', { name: 'Search' }).click();

    const productRow = page.locator('.product-item').filter({ hasText: 'Test Product Alpha' });
    await productRow.getByRole('button', { name: 'Edit' }).click();
    
    const qtyInput = productRow.locator('input[type="number"]');
    await qtyInput.fill('100');
    await productRow.getByRole('button', { name: 'Confirm' }).click();
    
    await expect(productRow.getByText('Qty: 100')).toBeVisible();
  });

  test('Negative: Negative Quantity', async ({ page }) => {
    await page.goto('/');
    const productRow = page.locator('.product-item').filter({ hasText: 'Test Product Alpha' });
    await productRow.getByRole('button', { name: 'Edit' }).click();
    
    const qtyInput = productRow.locator('input[type="number"]');
    await qtyInput.fill('-5');
    
    const isValid = await qtyInput.evaluate((el: HTMLInputElement) => el.checkValidity());
    expect(isValid).toBe(false);
  });

  test('Positive: Delete Product', async ({ page }) => {
    await page.goto('/');
    
    page.on('dialog', dialog => dialog.accept());

    const productRow = page.locator('.product-item').filter({ hasText: 'Test Product Alpha' });
    await productRow.getByRole('button', { name: 'Delete' }).click();
    
    await expect(page.locator('.product-item').filter({ hasText: 'Test Product Alpha' })).not.toBeVisible();
  });
});
