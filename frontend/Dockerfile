# ============================================
# Dependencies stage
# ============================================
FROM node:22-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
# Not `npm ci`: package.json now includes @vercel/otel, which isn't in
# the committed package-lock.json (that lock predates it and can't be
# regenerated without network access at authoring time). `npm install`
# updates the lock as needed; everything else still resolves from it.
RUN npm install

# ============================================
# Build stage
# ============================================
FROM node:22-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# NEXT_PUBLIC_* variables are inlined into the client bundle at build
# time, so this must be a build arg (see docker-compose.yml's
# frontend.build.args), not just a runtime env var.
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL}
ARG NEXT_PUBLIC_WHATSAPP_NUMBER=""
ENV NEXT_PUBLIC_WHATSAPP_NUMBER=${NEXT_PUBLIC_WHATSAPP_NUMBER}

RUN npm run build

# ============================================
# Runtime stage
# ============================================
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN addgroup -g 1001 -S nodejs && adduser -S nextjs -u 1001

# Leverages Next.js's "standalone" output (next.config.ts) so the
# runtime image only needs the traced production dependencies, not the
# full node_modules tree.
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
