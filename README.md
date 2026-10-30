# BotVote

เว็บไซต์ภาษาไทยสำหรับค้นหา แนะนำ โหวต และรีวิวบอท Discord — GitHub Pages + Supabase

## เว็บไซต์
- หน้าเว็บหลัก: https://chloerangersonic0909-cmd.github.io/botvote-th-/
- Developer Portal: https://chloerangersonic0909-cmd.github.io/botvote-th-/developer.html
- Admin Dashboard: https://chloerangersonic0909-cmd.github.io/botvote-th-/admin.html

## ตั้งค่าฐานข้อมูล

1. เปิด [Supabase SQL Editor](https://supabase.com/dashboard/project/crgjfdbdccpqumqaiuyq/sql/new).
2. รัน `supabase/botvote-schema.sql` ก่อน เพื่อสร้างตารางบอทและคะแนนโหวต
3. รัน `supabase/production-hardening.sql` เพื่อสร้างตารางรีวิวและกำหนดสิทธิ์การอ่าน/แก้ไขหลังบ้านให้ถูกต้อง
4. ตั้งค่า **Authentication → URL Configuration → Redirect URLs** ให้มี:
   `https://chloerangersonic0909-cmd.github.io/botvote-th-/**`
5. ตั้งค่า **Authentication → Rate Limits / SMTP** ให้เหมาะสม หากการส่งอีเมลยืนยันถูกจำกัด
6. กำหนดสิทธิ์แอดมินใน Supabase Dashboard ที่ Authentication → Users โดยใช้ `app_metadata.role = admin` ผ่านเครื่องมือที่เชื่อถือได้ ห้ามใช้ `user_metadata` สำหรับสิทธิ์
7. รัน `supabase/admin-rls.sql` เพื่อให้แอดมินอ่านคำขอทั้งหมดและอัปเดตได้เฉพาะคอลัมน์สถานะ
8. ออกจากระบบแล้วเข้าสู่ระบบใหม่ เพื่อรับ JWT ที่มี role ล่าสุด

## ฟังก์ชันที่โค้ดรองรับ
- ค้นหา/กรอง/เรียงบอทที่ได้รับอนุมัติ
- ส่งคำขอบอทหลังเข้าสู่ระบบ โดยเริ่มเป็น `pending`
- โหวตได้ครั้งเดียวต่อผู้ใช้ต่อบอท ด้วย unique constraint และ RLS
- รีวิวคะแนน 1–5 ดาวและข้อความ โดยจำกัดหนึ่งรีวิวต่อผู้ใช้ต่อบอท (ต้องรัน migration)
- Developer Portal แสดงรายการและสถิติของบอทเจ้าของบัญชี
- Admin Dashboard สำหรับตรวจสอบและอนุมัติ/ปฏิเสธคำขอ

## ความปลอดภัย
- ใช้เฉพาะ Supabase publishable/anon key ฝั่งหน้าเว็บ และเปิด RLS
- ห้ามใส่ `service_role` หรือ secret key ใน HTML/JavaScript สาธารณะ
- ห้ามให้ผู้ใช้ส่ง Bot Token, รหัสผ่าน Discord หรือ secret
- การจำกัดหนึ่งโหวตต่อบัญชีไม่ได้ป้องกันการสร้างหลายบัญชีได้ทั้งหมด
- GitHub Pages เป็น static hosting; งานที่ต้องใช้ความลับหรือการตรวจสอบฝั่งเซิร์ฟเวอร์ต้องทำผ่าน Supabase/RLS/Edge Functions ไม่ใช่ซ่อน key ใน JavaScript

## หมายเหตุ
การแก้โค้ดและ commit ไม่ได้ยืนยันว่าการตั้งค่า Supabase ได้รันแล้วหรือว่า GitHub Pages deploy เสร็จ ต้องตรวจสอบใน Supabase และทดสอบจริงหลัง deploy
