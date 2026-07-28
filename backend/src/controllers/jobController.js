import prisma from '../config/database.js';

export const getJobById = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const jobId = parseInt(req.params.id);
    if (!userId) return res.status(403).json({ success: false, message: 'Forbidden' });

    const job = await prisma.item_upload_jobs.findUnique({
      where: { iuj_id: jobId },
      include: { closet_items: true }
    });

    if (!job || job.closet_items?.ci_usr_id !== userId) {
      return res.status(404).json({ success: false, message: 'Job not found' });
    }

    res.status(200).json({
      success: true,
      data: {
        id: job.iuj_id,
        itemId: job.iuj_ci_id,
        status: job.iuj_status,
        imageUrl: job.iuj_image_url,
        lastError: job.iuj_last_error
      }
    });
  } catch (error) {
    console.error('Error fetching job:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch job' });
  }
};
