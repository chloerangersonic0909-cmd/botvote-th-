# BotVote

เว็บไซต์ภาษาไทยสำหรับค้นหาและแนะนำบอท Discord — โฮสต์ด้วย GitHub Pages และใช้ Supabase เป็นฐานข้อมูลกลาง

## เว็บไซต์
https://chloerangersonic0909-cmd.github.io/botvote-th-/

## ตั้งค่าฐานข้อมูลกลาง (ทำครั้งเดียว)

1. เปิด Supabase Dashboard ของโปรเจกต์ที่ต้องการใช้
2. ไปที่ **SQL Editor** แล้วเปิดไฟล์ [supabase/botvote-schema.sql](supabase/botvote-schema.sql) ใน repository นี้
3. คัดลอก SQL ทั้งหมดไปวางใน SQL Editor แล้วกด **Run**.
4. ใน Supabase ไปที่ **Project Settings → API** (หรือ **Data API / API Keys** ตามหน้าตา Dashboard) แล้วคัดลอก **publishable/anon key** ของโปรเจกต์ ห้ามใช้ `service_role` หรือ secret key ในหน้าเว็บ
5. เปิด `index.html` ใน GitHub แล้วกด Edit (ดินสอ) ค้นหา `PASTE_YOUR_SUPABASE_ANON_KEY_HERE` แล้วแทนที่ด้วย publishable/anon key ที่คัดลอกมา จากนั้น Commit changes
6. ใน Supabase ไปที่ **Authentication → URL Configuration** แล้วเพิ่ม URL นี้ใน **Redirect URLs**:
   `https://chloerangersonic0909-cmd.github.io/botvote-th-/**`
7. รอ GitHub Pages deploy เสร็จ แล้วเปิดเว็บใหม่ เข้าสู่ระบบด้วยอีเมลเพื่อส่งบอทและกดใจ

## ระบบปัจจุบัน
- รายการบอทที่อนุมัติแล้วอ่านได้จากฐานข้อมูลกลาง
- การส่งบอทต้องเข้าสู่ระบบด้วยลิงก์ยืนยันอีเมล และรายการใหม่จะเป็น `pending` จนกว่าผู้ดูแลจะอนุมัติ
- การกดใจต้องเข้าสู่ระบบ
- ตาราง `botvote_votes` มีข้อจำกัด unique ที่ `(bot_id, user_id)` และนโยบาย RLS เพื่อป้องกันผู้ใช้คนเดิมกดใจบอทเดิมซ้ำ แม้จะพยายามเรียก API โดยตรง
- ไม่ขอ Bot Token หรือ service_role key
- ออกแบบรองรับมือถือและภาษาไทย

## อนุมัติบอท
เพื่อป้องกันสแปม รายการที่ส่งใหม่จะยังไม่แสดงสาธารณะโดยอัตโนมัติ ผู้ดูแลสามารถตรวจสอบแถวในตาราง `botvote_bots` ผ่าน Supabase Table Editor และเปลี่ยน `status` จาก `pending` เป็น `approved` เมื่อแน่ใจว่าข้อมูลถูกต้อง

## หมายเหตุด้านความปลอดภัย
publishable/anon key ออกแบบมาให้ใช้ใน frontend ได้เมื่อเปิดใช้ RLS และ policies ตาม schema นี้แล้ว ห้ามเผยแพร่ `service_role` key หรือ secret key เด็ดขาด การใช้ email OTP ช่วยผูกคะแนนกับบัญชีผู้ใช้ แต่ไม่ได้ป้องกันคนสร้างหลายบัญชีได้อย่างสมบูรณ์

สร้างเว็บไซต์โดย ChatGPT · OpenAI
