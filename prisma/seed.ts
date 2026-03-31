import prisma from '../lib/prisma'

async function main() {
  await prisma.product.createMany({
    data: [
      { name: 'Laptop Pro', sku: 'LP-001', quantity: 15 },
      { name: 'Wireless Mouse', sku: 'WM-002', quantity: 50 },
      { name: 'Mechanical Keyboard', sku: 'MK-003', quantity: 30 },
    ],
  })
  console.log('Seeded database with products.')
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
