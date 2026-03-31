import NextAuth from "next-auth"
import Google from "next-auth/providers/google"
import { PrismaAdapter } from "@auth/prisma-adapter"
import prisma from "./lib/prisma"

export const { handlers, auth, signIn, signOut } = NextAuth({
  trustHost: true,
  adapter: PrismaAdapter(prisma),
  providers: [
    Google({
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    }),
  ],
  callbacks: {
    async signIn({ user, account, profile }) {
      if (account?.provider === "google" && user.email) {
        // Automatically add if they are listed in INITIAL_ALLOWED_EMAILS and not in db yet
        const initialEmails = (process.env.INITIAL_ALLOWED_EMAILS || "").split(",").map(e => e.trim());
        if (initialEmails.includes(user.email)) {
          await prisma.allowedUser.upsert({
            where: { email: user.email },
            update: {},
            create: { email: user.email },
          });
        }
        
        // Check if user's email exists in AllowedUser
        const allowedUser = await prisma.allowedUser.findUnique({
          where: { email: user.email },
        });

        if (allowedUser) {
          return true; // Allowed to sign in
        } else {
          return false; // Unauthorized
        }
      }
      return false;
    },
  },
})
