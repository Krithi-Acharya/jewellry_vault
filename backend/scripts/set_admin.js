/**
 * set_admin.js
 *
 * Grants (or revokes) the admin role for a user by email. Idempotent — safe
 * to run more than once.
 *
 * Usage:
 *   node scripts/set_admin.js user@example.com            # grant admin
 *   node scripts/set_admin.js user@example.com --revoke    # back to 'user'
 */
import 'dotenv/config';
import prisma from '../src/config/database.js';

const email = process.argv[2];
const revoke = process.argv.includes('--revoke');

if (!email) {
  console.error('Usage: node scripts/set_admin.js <email> [--revoke]');
  process.exitCode = 1;
} else {
  const role = revoke ? 'user' : 'admin';

  const main = async () => {
    const user = await prisma.users.findUnique({ where: { usr_email: email } });

    if (!user) {
      console.error(`No user found with email ${email}. They must sign in at least once first.`);
      process.exitCode = 1;
      return;
    }

    if (user.usr_role === role) {
      console.log(`${email} already has role '${role}'. Nothing to do.`);
      return;
    }

    await prisma.users.update({
      where: { usr_id: user.usr_id },
      data: { usr_role: role },
    });

    console.log(`${email}: '${user.usr_role}' -> '${role}'`);
  };

  main()
    .catch((error) => {
      console.error('Failed to set role:', error);
      process.exitCode = 1;
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
