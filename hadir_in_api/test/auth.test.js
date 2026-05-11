const request = require('supertest');
const express = require('express');

// Mock controllers and middlewares to prevent actual database/network calls during tests
jest.mock('../controllers/authController', () => ({
  register: jest.fn(),
  login: jest.fn(),
  googleLogin: jest.fn(),
  verifyOTP: jest.fn(),
  getMe: jest.fn(),
  updateProfile: jest.fn()
}));

jest.mock('../middleware/authMiddleware', () => jest.fn());

const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

// Mount routes
const authRoutes = require('../routes/authRoutes');
const app = express();
app.use(express.json());
app.use('/api/auth', authRoutes);

describe('Auth API (Mocked Routes)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /api/auth/register', () => {
    it('should register successfully and return 201', async () => {
      // Arrange
      authController.register.mockImplementation((req, res) => {
        return res.status(201).json({ message: 'User registered successfully' });
      });

      // Act
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          name: 'New User',
          email: 'newuser@example.com',
          password: 'password123'
        });
        
      // Assert
      expect(response.statusCode).toBe(201);
      expect(response.body).toHaveProperty('message', 'User registered successfully');
      expect(authController.register).toHaveBeenCalledTimes(1);
    });
  });

  describe('POST /api/auth/login', () => {
    it('should login successfully with correct credentials', async () => {
      // Arrange
      authController.login.mockImplementation((req, res) => {
        return res.status(200).json({ token: 'mock_token', user: { id: 1, name: 'Test' } });
      });

      // Act
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'password123'
        });
        
      // Assert
      expect(response.statusCode).toBe(200);
      expect(response.body).toHaveProperty('token');
      expect(authController.login).toHaveBeenCalledTimes(1);
    });

    it('should fail with incorrect credentials', async () => {
      // Arrange
      authController.login.mockImplementation((req, res) => {
        return res.status(401).json({ error: 'Invalid credentials' });
      });

      // Act
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'wrongpassword'
        });
        
      // Assert
      expect(response.statusCode).toBe(401);
      expect(response.body).toHaveProperty('error');
    });
  });

  describe('GET /api/auth/me (Protected Route)', () => {
    it('should return user profile if token is valid', async () => {
      // Arrange
      // Simulate authMiddleware successfully validating token and calling next()
      authMiddleware.mockImplementation((req, res, next) => {
        req.user = { id: 1 }; // Inject user data to request
        next();
      });

      authController.getMe.mockImplementation((req, res) => {
        return res.status(200).json({ id: req.user.id, name: 'Valid User' });
      });

      // Act
      const response = await request(app)
        .get('/api/auth/me')
        .set('Authorization', 'Bearer mock_valid_token');

      // Assert
      expect(response.statusCode).toBe(200);
      expect(response.body).toHaveProperty('name', 'Valid User');
      expect(authMiddleware).toHaveBeenCalledTimes(1);
      expect(authController.getMe).toHaveBeenCalledTimes(1);
    });

    it('should return 401 Unauthorized if no token provided', async () => {
      // Arrange
      // Simulate authMiddleware blocking the request due to missing token
      authMiddleware.mockImplementation((req, res, next) => {
        return res.status(401).json({ error: 'Unauthorized' });
      });

      // Act
      const response = await request(app)
        .get('/api/auth/me');

      // Assert
      expect(response.statusCode).toBe(401);
      expect(response.body).toHaveProperty('error', 'Unauthorized');
      expect(authController.getMe).not.toHaveBeenCalled();
    });
  });
});
