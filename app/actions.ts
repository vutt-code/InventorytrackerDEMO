'use server'

import { revalidatePath } from 'next/cache'
import prisma from '../lib/prisma'
import { auth } from '../auth'

export async function getProducts(query?: string) {
  const session = await auth()
  if (!session?.user) throw new Error('Unauthorized')

  if (query) {
    return prisma.product.findMany({
      where: {
        OR: [
          { name: { contains: query } },
          { sku: { contains: query } }
        ]
      },
      orderBy: { createdAt: 'desc' }
    })
  }
  return prisma.product.findMany({
    orderBy: { createdAt: 'desc' }
  })
}

export async function createProduct(formData: FormData) {
  const session = await auth()
  if (!session?.user) return { error: 'Unauthorized' }

  const name = formData.get('name') as string
  const sku = formData.get('sku') as string
  const quantity = parseInt(formData.get('quantity') as string, 10)

  if (!name || !sku || isNaN(quantity) || quantity < 0) {
    return { error: 'Invalid input' }
  }

  try {
    await prisma.product.create({
      data: { name, sku, quantity }
    })
    revalidatePath('/')
    return { success: true }
  } catch (e: any) {
    if (e.code === 'P2002') {
      return { error: 'A product with this SKU already exists.' }
    }
    return { error: 'Failed to create product.' }
  }
}

export async function updateQuantity(id: number, newQuantity: number) {
  const session = await auth()
  if (!session?.user) throw new Error('Unauthorized')

  if (isNaN(newQuantity) || newQuantity < 0) {
    throw new Error('Invalid quantity')
  }

  await prisma.product.update({
    where: { id },
    data: { quantity: newQuantity }
  })

  revalidatePath('/')
}

export async function deleteProduct(id: number) {
  const session = await auth()
  if (!session?.user) throw new Error('Unauthorized')

  await prisma.product.delete({
    where: { id }
  })

  revalidatePath('/')
}
