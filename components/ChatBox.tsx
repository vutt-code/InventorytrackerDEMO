'use client';

import { useState, useRef, useEffect } from 'react';

type Message = { role: 'user' | 'assistant'; content: string };

export default function ChatBox() {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom of chat
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;

    const userMsg: Message = { role: 'user', content: input };
    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setIsLoading(true);

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: [...messages, userMsg] })
      });

      if (!response.body) throw new Error('No body');

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      
      setMessages(prev => [...prev, { role: 'assistant', content: '' }]);

      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        
        const chunk = decoder.decode(value, { stream: true });
        setMessages(prev => {
          const updated = [...prev];
          updated[updated.length - 1].content += chunk;
          return updated;
        });
      }
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <>
      {!isOpen && (
        <button
          onClick={() => setIsOpen(true)}
          style={{
            position: 'fixed',
            bottom: '24px',
            right: '24px',
            background: 'linear-gradient(135deg, #6366f1 0%, #a855f7 100%)',
            color: 'white',
            border: 'none',
            borderRadius: '32px',
            padding: '0 24px',
            height: '64px',
            boxShadow: '0 10px 25px rgba(168,85,247,0.4)',
            cursor: 'pointer',
            fontSize: '16px',
            fontWeight: '600',
            letterSpacing: '0.5px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '12px',
            zIndex: 1000,
            transition: 'transform 0.2s ease, box-shadow 0.2s ease',
          }}
          aria-label="Open AI Chat"
          onMouseEnter={(e) => (e.currentTarget.style.transform = 'scale(1.05)')}
          onMouseLeave={(e) => (e.currentTarget.style.transform = 'scale(1)')}
        >
          <span style={{ fontSize: '24px' }}>✨</span> Ask Architect AI
        </button>
      )}

      {isOpen && (
        <div
          style={{
            position: 'fixed',
            bottom: '24px',
            right: '24px',
            width: '760px',
            height: '600px',
            backgroundColor: '#121214',
            border: '1px solid #27272a',
            borderRadius: '16px',
            boxShadow: '0 20px 40px rgba(0,0,0,0.5)',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
            zIndex: 1000,
            fontFamily: 'Inter, system-ui, sans-serif',
            color: '#e4e4e7',
          }}
        >
          {/* Header */}
          <div
            style={{
              background: 'linear-gradient(90deg, #18181b 0%, #27272a 100%)',
              borderBottom: '1px solid #3f3f46',
              padding: '16px 20px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div style={{ fontSize: '20px' }}>✨</div>
              <h3 style={{ margin: 0, fontSize: '16px', fontWeight: '600', letterSpacing: '0.5px' }}>Architecture AI</h3>
            </div>
            <button
              onClick={() => setIsOpen(false)}
              style={{
                background: 'transparent',
                border: 'none',
                color: '#a1a1aa',
                fontSize: '24px',
                cursor: 'pointer',
                transition: 'color 0.2s',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.color = 'white')}
              onMouseLeave={(e) => (e.currentTarget.style.color = '#a1a1aa')}
              aria-label="Close Chat"
            >
              ×
            </button>
          </div>

          {/* Messages Area */}
          <div style={{ flex: 1, padding: '20px', overflowY: 'auto', backgroundColor: '#121214' }}>
            {messages.length === 0 && (
              <div style={{ textAlign: 'center', marginTop: '40px', color: '#a1a1aa' }}>
                <div style={{ fontSize: '40px', marginBottom: '16px' }}>🏗️</div>
                <p style={{ fontSize: '15px', lineHeight: '1.5' }}>
                  Ask me anything about the application architecture, AWS setup, or database!
                </p>
              </div>
            )}
            
            {messages.map((m, idx) => (
              <div
                key={idx}
                style={{
                  marginBottom: '16px',
                  display: 'flex',
                  justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start',
                }}
              >
                <div
                  style={{
                    maxWidth: '85%',
                    padding: '12px 16px',
                    borderRadius: '18px',
                    borderBottomRightRadius: m.role === 'user' ? '4px' : '18px',
                    borderBottomLeftRadius: m.role === 'assistant' ? '4px' : '18px',
                    backgroundColor: m.role === 'user' ? '#6366f1' : '#27272a',
                    color: m.role === 'user' ? '#ffffff' : '#e4e4e7',
                    fontSize: m.role === 'assistant' ? '14px' : '14.5px',
                    fontWeight: m.role === 'assistant' ? '300' : '400',
                    fontStretch: 'condensed',
                    lineHeight: '1.4',
                    wordWrap: 'break-word',
                    whiteSpace: 'pre-wrap', // Preserves formatting/newlines from AI
                    boxShadow: '0 2px 5px rgba(0,0,0,0.1)',
                  }}
                >
                  <strong style={{ display: 'block', marginBottom: '6px', fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.5px', opacity: m.role === 'user' ? 0.9 : 0.6 }}>
                    {m.role === 'user' ? 'You' : 'Architect AI'}
                  </strong>
                  {m.content}
                </div>
              </div>
            ))}
            {isLoading && (
              <div style={{ display: 'flex', justifyContent: 'flex-start', marginBottom: '16px' }}>
                 <div style={{ padding: '12px 16px', borderRadius: '18px', borderBottomLeftRadius: '4px', backgroundColor: '#27272a', fontSize: '14px', color: '#a1a1aa' }}>
                   Analyzing architecture...
                 </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Input Area */}
          <form
            onSubmit={handleSubmit}
            style={{
              padding: '16px',
              borderTop: '1px solid #27272a',
              display: 'flex',
              gap: '12px',
              backgroundColor: '#18181b',
            }}
          >
            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder="Ask a technical question..."
              style={{
                flex: 1,
                padding: '12px 16px',
                borderRadius: '12px',
                border: '1px solid #3f3f46',
                backgroundColor: '#27272a',
                color: '#ffffff',
                outline: 'none',
                fontSize: '14px',
                transition: 'border-color 0.2s',
              }}
              onFocus={(e) => (e.currentTarget.style.borderColor = '#6366f1')}
              onBlur={(e) => (e.currentTarget.style.borderColor = '#3f3f46')}
              disabled={isLoading}
            />
            <button
              type="submit"
              disabled={isLoading || !input.trim()}
              style={{
                background: 'linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%)',
                color: 'white',
                border: 'none',
                borderRadius: '12px',
                padding: '0 20px',
                fontWeight: '600',
                cursor: isLoading || !input.trim() ? 'not-allowed' : 'pointer',
                opacity: isLoading || !input.trim() ? 0.5 : 1,
                transition: 'opacity 0.2s',
              }}
            >
              Send
            </button>
          </form>
        </div>
      )}
    </>
  );
}
