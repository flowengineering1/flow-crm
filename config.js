// การตั้งค่าเชื่อมต่อฐานข้อมูล Supabase ของ Flow CRM
// ใช้เมื่อเปิดแอปจาก GitHub Pages หรือโดเมนของบริษัท (ไฟล์ index.html)
//
// วิธีหาค่า: Supabase Dashboard → Project Settings → API
//   - Project URL        → ใส่ใน url
//   - anon public key    → ใส่ใน anonKey
// ห้ามนำ service_role key มาใส่ที่นี่เด็ดขาด (เป็นกุญแจลับ ใช้ได้เฉพาะฝั่งเซิร์ฟเวอร์)
//
// ถ้าปล่อยว่างทั้งสองค่า แอปจะทำงานแบบบันทึกข้อมูลในเครื่องเท่านั้น
// selfSignup: false = ผู้ดูแลสร้างบัญชีให้ใน Supabase (ซ่อนปุ่มสมัครในแอป), true = พนักงานสมัครเองแล้วรออนุมัติ
window.FLOW_SUPABASE = {
  url: 'https://voyqlxixtnqpikqphtvl.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZveXFseGl4dG5xcGlrcXBodHZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4NDMwMDAsImV4cCI6MjEwODQxOTAwMH0.ha7wVAjbfUN4cYzPELRR_SQgwm3Q9dmDCE63hp0y8z0',
  selfSignup: false,
  // โดเมนสมมติที่ต่อท้ายชื่อผู้ใช้ให้เป็นอีเมลภายใน (ผู้ใช้พิมพ์แค่ somchai ระบบใช้ somchai@flowcrm.local)
  loginDomain: 'flowcrm.local'
};
