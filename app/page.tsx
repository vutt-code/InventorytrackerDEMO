import { getProducts } from './actions'
import ProductClient from './ProductClient'
import { auth } from '../auth'
import { SignIn, SignOut } from '../components/auth-components'
import ChatBox from '../components/ChatBox'

export const dynamic = 'force-dynamic'

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>
}) {
  const session = await auth()

  if (!session?.user) {
    return (
      <main style={{ padding: '3rem 2rem', textAlign: 'center', maxWidth: '795px', margin: '0 auto', fontFamily: 'Inter, system-ui, sans-serif' }}>
        <h1 style={{ fontSize: '2.5rem', fontWeight: 'bold', marginBottom: '1rem', color: '#111827' }}>
          Inventory Tracker (AWS)
        </h1>
        <p style={{ color: '#4b5563', marginBottom: '2.5rem', fontSize: '1.1rem' }}>
          You are currently not logged in. Please sign in to securely access the inventory system.
        </p>
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: '3.5rem' }}>
          <SignIn />
        </div>
        
        <div style={{ 
          maxWidth: '75%',
          margin: '0 auto',
          borderRadius: '16px', 
          overflow: 'hidden', 
          boxShadow: '0 20px 40px -10px rgba(0,0,0,0.15), 0 0 1px 1px rgba(0,0,0,0.05)',
          border: '1px solid #e5e7eb',
          backgroundColor: '#ffffff'
        }}>
          <img 
            src="/preview.png" 
            alt="Inventory Tracker Application Preview" 
            style={{ width: '100%', height: 'auto', display: 'block', objectFit: 'contain' }} 
          />
        </div>
      </main>
    )
  }

  const params = await searchParams
  const query = params.q || ''
  const products = await getProducts(query)

  return (
    <main>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>Inventory Tracker (AWS)</h1>
        <div>
          <span style={{ marginRight: '1rem' }}>Logged in as {session.user.email}</span>
          <SignOut />
        </div>
      </div>
      <ProductClient initialProducts={products} query={query} />
      {/* AI Chatbox embedded here. Will be floating and fixed. */}
      <ChatBox />
    </main>
  )
}
