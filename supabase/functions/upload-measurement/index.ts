import { createClient } from "jsr:@supabase/supabase-js@2";

console.log("Hello from Functions!");

Deno.serve(async (req) => {
  // 1. Handle CORS (Optional, but good practice if called from browsers)
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    // 2. Parse the request body
    const body = await req.json();

    // 3. Initialize Supabase Client with Service Role Key
    // This allows us to bypass RLS and Auth requirements of the client
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 4. Call the RPC function
    // We pass the body directly, assuming it matches the RPC signature
    // (api_key, heating_id, measurements...)
    const { data, error } = await supabaseAdmin.rpc("upload_measurement", body);

    if (error) {
      console.error("RPC Error:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        headers: { "Content-Type": "application/json" },
        status: 400,
      });
    }

    // 5. Return success
    return new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    console.error("Function Error:", err);
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
