import prisma from '../config/database.js';

export const syncUser = async (req, res) => {
  try {
    const { uid, email } = req.user;
    const { displayName, firstName, lastName, photoUrl, phoneNumber } = req.body;
    
    // Check if user exists by Firebase UID
    let user = await prisma.users.findUnique({
      where: { usr_firebase_uid: uid }
    });

    if (!user) {
      // Fallback: check if they exist by email
      user = await prisma.users.findUnique({
        where: { usr_email: email }
      });
    }

    if (user) {
      // UPSERT: Update existing user
      user = await prisma.users.update({
        where: { usr_id: user.usr_id },
        data: {
          usr_firebase_uid: uid,
          ...(displayName !== undefined && { usr_display_name: displayName }),
          ...(firstName !== undefined && { usr_first_name: firstName }),
          ...(lastName !== undefined && { usr_last_name: lastName }),
          ...(photoUrl !== undefined && { usr_profile_picture_url: photoUrl }),
          ...(phoneNumber !== undefined && { usr_phone_number: phoneNumber })
        }
      });
    } else {
      // UPSERT: Create new user
      user = await prisma.users.create({
        data: {
          usr_firebase_uid: uid,
          usr_email: email,
          usr_display_name: displayName || null,
          usr_first_name: firstName || null,
          usr_last_name: lastName || null,
          usr_profile_picture_url: photoUrl || null,
          usr_phone_number: phoneNumber || null
        }
      });
    }

    res.status(200).json({
      status: 'SUCCESS',
      data: { user }
    });
  } catch (error) {
    console.error('Error syncing user:', error);
    res.status(500).json({
      status: 'ERROR',
      message: 'Failed to sync user'
    });
  }
};
