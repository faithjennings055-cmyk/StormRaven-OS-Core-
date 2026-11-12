import {
  pgTable,
  text,
  timestamp,
  boolean,
  serial,
} from "drizzle-orm/pg-core"

// --- Better Auth required tables -------------------------------------------
// Column names are camelCase to match Better Auth's defaults. Do not rename.

export const user = pgTable("user", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  emailVerified: boolean("emailVerified").notNull().default(false),
  image: text("image"),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
  updatedAt: timestamp("updatedAt").notNull().defaultNow(),
})

export const session = pgTable("session", {
  id: text("id").primaryKey(),
  expiresAt: timestamp("expiresAt").notNull(),
  token: text("token").notNull().unique(),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
  updatedAt: timestamp("updatedAt").notNull().defaultNow(),
  ipAddress: text("ipAddress"),
  userAgent: text("userAgent"),
  userId: text("userId")
    .notNull()
    .references(() => user.id, { onDelete: "cascade" }),
})

export const account = pgTable("account", {
  id: text("id").primaryKey(),
  accountId: text("accountId").notNull(),
  providerId: text("providerId").notNull(),
  userId: text("userId")
    .notNull()
    .references(() => user.id, { onDelete: "cascade" }),
  accessToken: text("accessToken"),
  refreshToken: text("refreshToken"),
  idToken: text("idToken"),
  accessTokenExpiresAt: timestamp("accessTokenExpiresAt"),
  refreshTokenExpiresAt: timestamp("refreshTokenExpiresAt"),
  scope: text("scope"),
  password: text("password"),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
  updatedAt: timestamp("updatedAt").notNull().defaultNow(),
})

export const verification = pgTable("verification", {
  id: text("id").primaryKey(),
  identifier: text("identifier").notNull(),
  value: text("value").notNull(),
  expiresAt: timestamp("expiresAt").notNull(),
  createdAt: timestamp("createdAt").defaultNow(),
  updatedAt: timestamp("updatedAt").defaultNow(),
})

// --- MÚSPELLHEIMR app tables -----------------------------------------------
// Scoped by userId (no RLS on Neon). No foreign keys by default.

// TOTP secrets for the time-gated 2FA handshake.
export const twoFactor = pgTable("two_factor", {
  id: serial("id").primaryKey(),
  userId: text("userId").notNull().unique(),
  secret: text("secret").notNull(),
  enabled: boolean("enabled").notNull().default(false),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
})

// Forensic ledger: every decision + intercepted threat is written here.
export const auditLog = pgTable("audit_log", {
  id: serial("id").primaryKey(),
  userId: text("userId").notNull(),
  daemon: text("daemon").notNull().default("Heimdallr"),
  category: text("category").notNull(),
  severity: text("severity").notNull().default("info"),
  message: text("message").notNull(),
  source: text("source"),
  createdAt: timestamp("createdAt").notNull().defaultNow(),
})
