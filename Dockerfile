# Stage 1: Base image
FROM node:20-alpine AS base

# Stage 2: Install dependencies
FROM base AS deps
RUN apk add --no-cache libc6-compat openssl
WORKDIR /app
COPY package.json package-lock.json ./
# Prisma schema is needed to generate client during npm install if postinstall script is used
COPY prisma ./prisma
RUN npm ci

# Stage 3: Build the application
FROM base AS builder
WORKDIR /app
RUN apk add --no-cache openssl
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Generate Prisma client for linux-musl
RUN npx prisma generate

# Build Next.js
ENV NEXT_TELEMETRY_DISABLED 1
RUN npm run build

# Stage 4: Production image
FROM base AS runner
WORKDIR /app
RUN apk add --no-cache openssl
# Install Prisma CLI so the ECS migration task doesn't have to download it at runtime
RUN npm install -g prisma@6

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# Run as non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy standalone build output from builder
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/prisma ./prisma
COPY --from=builder --chown=nextjs:nodejs /app/ARCHITECTURE.md ./ARCHITECTURE.md

USER nextjs

EXPOSE 3000
ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

# Note: Prisma migrations (prisma migrate deploy) should ideally be run
# outside the container (e.g., in a CI/CD pipeline step or Cloud Run job) 
# For simplicity, we'll start the server directly after pushing the database schema.
CMD ["sh", "-c", "npx prisma db push --skip-generate && node server.js"]