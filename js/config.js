// PTB TBK — Client configuration
// Replace these values with your Supabase project credentials.
// ONLY the public anon key belongs here. Never expose the service_role key.
const APP_CONFIG = {
  supabaseUrl: 'https://eguareofkzilfrnylqud.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVndWFyZW9ma3ppbGZybnlscXVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjEyOTgsImV4cCI6MjA5NjU5NzI5OH0.X-FdglNIGfN5XrcDFfp54GyQtEo9LqPNeZnv2k-1CDc',
  bankName: 'PTB TBK',
  currencySymbols: {
    USD: '$',
    BTC: '\u20BF'
  },
  pageSize: 10,
  // Offline fallback for the USD/HUF display rate (live rates come from the
  // exchange_rates table via js/fx.js).
  usdHufRate: 392.5,
  btcPriceApi: 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd'
};
