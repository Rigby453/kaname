import dotenv from 'dotenv';
import path from 'path';

// Загружаем .env до любых импортов prisma
dotenv.config({ path: path.resolve(__dirname, '.env') });
process.env['NODE_ENV'] = 'test';
// Если задан DATABASE_URL_TEST — переключаемся на него
if (process.env['DATABASE_URL_TEST']) {
  process.env['DATABASE_URL'] = process.env['DATABASE_URL_TEST'];
}
