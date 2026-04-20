-- AlterTable: Add email quota fields to users
ALTER TABLE "users" ADD COLUMN "emailQuota" INTEGER NOT NULL DEFAULT 50;
ALTER TABLE "users" ADD COLUMN "totalEmailsSent" INTEGER NOT NULL DEFAULT 0;

-- AlterTable: Add new event fields (in case they don't exist yet)
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "contactEmail" TEXT;
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "ticketTemplateUrl" TEXT;
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "ticketConfig" JSONB;
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "inviteCode" TEXT;

-- CreateUniqueIndex for inviteCode if not exists
CREATE UNIQUE INDEX IF NOT EXISTS "events_inviteCode_key" ON "events"("inviteCode");

-- CreateTable for event_committees if not exists
CREATE TABLE IF NOT EXISTS "event_committees" (
    "id" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "role" TEXT NOT NULL DEFAULT 'panitia',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_committees_pkey" PRIMARY KEY ("id")
);

-- CreateUniqueIndex for event_committees
CREATE UNIQUE INDEX IF NOT EXISTS "event_committees_eventId_userId_key" ON "event_committees"("eventId", "userId");

-- AddForeignKey for event_committees if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'event_committees_eventId_fkey'
  ) THEN
    ALTER TABLE "event_committees" ADD CONSTRAINT "event_committees_eventId_fkey" 
      FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'event_committees_userId_fkey'
  ) THEN
    ALTER TABLE "event_committees" ADD CONSTRAINT "event_committees_userId_fkey" 
      FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;
