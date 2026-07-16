import prisma from '../config/database.js';

export const syncUser = async (req, res) => {
  try {
    const { uid, email } = req.user;
    
    // Check if user exists in the database
    let user = await prisma.users.findUnique({
      where: { usr_firebase_uid: uid }
    });

    // If not by UID, maybe by email? (If they existed before Firebase)
    if (!user) {
      user = await prisma.users.findUnique({
        where: { usr_email: email }
      });

      if (user) {
        // Update existing user with Firebase UID
        user = await prisma.users.update({
          where: { usr_id: user.usr_id },
          data: { usr_firebase_uid: uid }
        });
      } else {
        // Create new user
        user = await prisma.users.create({
          data: {
            usr_firebase_uid: uid,
            usr_email: email,
            // You can extract additional defaults here if passed in req.body
          }
        });
      }
    }

    res.status(200).json({
      status: 'SUCCESS',
      data: {
        user
      }
    });
  } catch (error) {
    console.error('Error syncing user:', error);
    res.status(500).json({
      status: 'ERROR',
      message: 'Failed to sync user'
    });
  }
};
