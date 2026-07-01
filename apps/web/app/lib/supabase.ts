import { createClient } from "@supabase/supabase-js";

import { requiredEnv } from "./dodo";

export function getSupabaseClient() {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}
