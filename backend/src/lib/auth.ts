import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";

const phoneSchema = z
  .string()
  .min(8)
  .max(20)
  .regex(/^\+[1-9]\d{6,14}$/, "Use E.164 format, e.g. +14155552671");

export const registerSchema = z.object({
  phoneE164: phoneSchema,
  password: z.string().min(8).max(128),
  displayName: z.string().max(120).optional().default(""),
});

export const loginSchema = z.object({
  phoneE164: phoneSchema,
  password: z.string().min(1).max(128),
});

export type JwtPayload = {
  sub: string;
  phone: string;
};

export function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, 12);
}

export function verifyPassword(plain: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plain, hash);
}

export function signAccessToken(payload: JwtPayload): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET is not set");
  return jwt.sign(payload, secret, { expiresIn: "30d", algorithm: "HS256" });
}

export function verifyAccessToken(token: string): JwtPayload {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET is not set");
  const decoded = jwt.verify(token, secret) as JwtPayload;
  return decoded;
}

export function bearerFromAuthHeader(
  header: string | null,
): string | null {
  if (!header?.startsWith("Bearer ")) return null;
  return header.slice("Bearer ".length).trim() || null;
}
