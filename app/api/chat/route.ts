import { GoogleGenAI } from '@google/genai';
import { auth } from '../../../auth';
import { promises as fs } from 'fs';
import path from 'path';

let architectureContext = '';

export async function POST(req: Request) {
  const session = await auth();

  // 1. Authorize user
  if (!session?.user?.email) {
    return new Response('Unauthorized', { status: 401 });
  }

  // 2. Load context
  if (!architectureContext) {
    try {
      const filePath = path.join(process.cwd(), 'ARCHITECTURE.md');
      architectureContext = await fs.readFile(filePath, 'utf-8');
    } catch (e) {
      console.error('Failed to read ARCHITECTURE.md:', e);
      architectureContext = 'Architecture details unavailable.';
    }
  }

  const { messages } = await req.json();

  // Configure Gen AI
  const apiKey = process.env.GEMINI_API_KEY || '';
  const ai = new GoogleGenAI(apiKey ? { apiKey } : {});

  // System instruction
  const systemInstruction = `You are a helpful AI assistant built into the Inventory Tracker application. 
Your primary purpose is to help developers and users understand the architecture and technical implementation of this web app.
Here is the context from the ARCHITECTURE.md file:
---
${architectureContext}
---
Be concise, polite, and helpful. Format your responses using markdown.`;

  // Format messages
  const formattedContents = messages.map((m: any) => ({
    role: m.role === 'user' ? 'user' : 'model',
    parts: [{ text: m.content }]
  }));

  try {
    const stream = await ai.models.generateContentStream({
      model: 'gemini-2.5-flash',
      contents: formattedContents,
      config: { systemInstruction }
    });

    const readableStream = new ReadableStream({
      async start(controller) {
        for await (const chunk of stream) {
          if (chunk.text) {
            controller.enqueue(new TextEncoder().encode(chunk.text));
          }
        }
        controller.close();
      }
    });

    return new Response(readableStream, {
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-cache, no-transform'
      }
    });
  } catch (error: any) {
    console.error('Gemini API Error:', error);
    return new Response('AI is currently unavailable.', { status: 500 });
  }
}
