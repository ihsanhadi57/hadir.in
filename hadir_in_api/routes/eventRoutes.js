const express = require('express');
const router = express.Router();
const multer = require('multer');
const eventController = require('../controllers/eventController');
const authMiddleware = require('../middleware/authMiddleware');

const uploadTemplate = multer({ dest: 'uploads/templates/' });
const uploadEventImage = multer({ dest: 'uploads/events/' });

// Semua rute event memerlukan login
router.use(authMiddleware);

router.post('/', eventController.createEvent);
router.get('/', eventController.getMyEvents);
router.put('/:eventId', eventController.updateEvent);
router.delete('/:eventId', eventController.deleteEvent);

// Image upload route
router.post('/:eventId/image', uploadEventImage.single('image'), eventController.uploadEventImage);

// Template Designer routes
router.get('/:eventId/template', eventController.getEventTemplate);
router.post('/:eventId/template', uploadTemplate.single('image'), eventController.uploadTemplate);
router.put('/:eventId/template-config', eventController.updateTemplateConfig);

// Collaboration routes
router.post('/join/:code', eventController.joinEvent);

module.exports = router;
