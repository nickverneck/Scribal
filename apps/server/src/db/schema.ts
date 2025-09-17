import { pgTable, serial, text, timestamp, varchar } from 'drizzle-orm/pg-core';

export const transcripts = pgTable('transcripts', {
  id: serial('id').primaryKey(),
  roomId: varchar('room_id', { length: 128 }).notNull(),
  userId: varchar('user_id', { length: 128 }).notNull(),
  username: varchar('username', { length: 128 }).notNull(),
  content: text('content').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Transcript = typeof transcripts.$inferSelect;
export type NewTranscript = typeof transcripts.$inferInsert;

