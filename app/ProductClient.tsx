'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createProduct, updateQuantity, deleteProduct } from './actions'

type Product = {
  id: number
  name: string
  sku: string
  quantity: number
}

export default function ProductClient({ 
  initialProducts,
  query
}: { 
  initialProducts: Product[],
  query: string
}) {
  const router = useRouter()
  const [search, setSearch] = useState(query)
  const [isAdding, setIsAdding] = useState(false)
  const [editingId, setEditingId] = useState<number | null>(null)
  const [editQty, setEditQty] = useState<number | string>('')
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault()
    router.push(`/?q=${encodeURIComponent(search)}`)
  }

  const handleAddProduct = async (formData: FormData) => {
    setErrorMsg(null)
    const result = await createProduct(formData)
    if (result && result.error) {
      setErrorMsg(result.error)
    } else {
      setIsAdding(false)
    }
  }

  const handleUpdateQuantity = async (id: number, quantity: number) => {
    if (quantity < 0) return
    await updateQuantity(id, quantity)
  }

  const handleDelete = async (id: number) => {
    if (window.confirm('Are you sure you want to delete this product?')) {
      await deleteProduct(id)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
      <div className="card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
          <form onSubmit={handleSearch} style={{ flexDirection: 'row', gap: '0.5rem', flex: 1, marginRight: '1rem' }}>
            <input 
              type="search" 
              placeholder="Search by Name or SKU..." 
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{ marginBottom: 0, flex: 1 }}
            />
            <button type="submit" className="secondary">Search</button>
          </form>
          <button onClick={() => setIsAdding(!isAdding)}>
            {isAdding ? 'Cancel' : 'Add Product'}
          </button>
        </div>

        {isAdding && (
          <form action={handleAddProduct} id="add-product-form" style={{ marginTop: '1rem', borderTop: '1px solid var(--border-color)', paddingTop: '1rem' }}>
            <h2 style={{ marginBottom: '1rem' }}>Add New Product</h2>
            {errorMsg && (
              <div style={{ color: 'var(--danger-color)', marginBottom: '1rem', fontWeight: 'bold' }}>
                {errorMsg}
              </div>
            )}
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="name">Name</label>
                <input type="text" id="name" name="name" required />
              </div>
              <div className="form-group">
                <label htmlFor="sku">SKU</label>
                <input type="text" id="sku" name="sku" required />
              </div>
              <div className="form-group">
                <label htmlFor="quantity">Quantity</label>
                <input type="number" id="quantity" name="quantity" min="0" required defaultValue="0" />
              </div>
            </div>
            <button type="submit">Save Product</button>
          </form>
        )}
      </div>

      <div className="card product-list">
        {initialProducts.length === 0 ? (
          <div style={{ textAlign: 'center', color: '#aaa', padding: '2rem' }}>
            No products found.
          </div>
        ) : (
          initialProducts.map(product => (
            <div key={product.id} className="product-item">
              <div className="product-info">
                <h3>{product.name}</h3>
                <p>SKU: {product.sku}</p>
              </div>
              <div className="product-actions" style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                {editingId === product.id ? (
                  <>
                    <input 
                      type="number" 
                      min="0"
                      value={editQty}
                      onChange={(e) => setEditQty(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          handleUpdateQuantity(product.id, Number(editQty))
                          setEditingId(null)
                        } else if (e.key === 'Escape') {
                          setEditingId(null)
                        }
                      }}
                      title="Update quantity"
                      autoFocus
                      style={{ width: '80px', marginBottom: 0 }}
                    />
                    <button 
                      className="secondary"
                      onClick={() => {
                        handleUpdateQuantity(product.id, Number(editQty))
                        setEditingId(null)
                      }}
                    >
                      Confirm
                    </button>
                    <button 
                      className="secondary"
                      onClick={() => setEditingId(null)}
                    >
                      Cancel
                    </button>
                  </>
                ) : (
                  <>
                    <span style={{ minWidth: '4rem', textAlign: 'center', fontWeight: 'bold' }}>
                      Qty: {product.quantity}
                    </span>
                    <button 
                      className="secondary"
                      onClick={() => {
                        setEditingId(product.id)
                        setEditQty(product.quantity)
                      }}
                    >
                      Edit 
                    </button>
                  </>
                )}
                <button 
                  className="danger" 
                  onClick={() => handleDelete(product.id)}
                  title="Delete product"
                >
                  Delete
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
