const express = require('express');
const { v4: uuidv4 } = require('uuid');

/**
 * Mock API server to simulate the user service for Lambda testing
 */
class MockApiServer {
  constructor(port = 8443) {
    this.app = express();
    this.port = port;
    this.users = new Map(); // In-memory user storage for testing
    this.requests = []; // Store requests for verification
    
    this.setupMiddleware();
    this.setupRoutes();
  }

  setupMiddleware() {
    this.app.use(express.json());
    
    // Logging middleware
    this.app.use((req, res, next) => {
      console.log(`${req.method} ${req.path}`, req.body);
      this.requests.push({
        method: req.method,
        path: req.path,
        body: req.body,
        headers: req.headers,
        timestamp: new Date()
      });
      next();
    });

    // Auth middleware for internal endpoints
    this.app.use('/api/v1/internal', (req, res, next) => {
      const apiKey = req.headers['x-internal-api-key'];
      if (!apiKey || (apiKey !== 'dev-internal-key' && apiKey !== 'test-internal-key')) {
        return res.status(401).json({ error: 'Invalid or missing internal API key' });
      }
      next();
    });
  }

  setupRoutes() {
    // Health check
    this.app.get('/health', (req, res) => {
      res.json({ status: 'healthy', timestamp: new Date().toISOString() });
    });

    // Internal user activation endpoint (called by post-confirmation Lambda)
    this.app.post('/api/v1/internal/user/activate', (req, res) => {
      try {
        const { action, data } = req.body;
        
        if (action !== 'activateUser') {
          return res.status(400).json({ error: 'Invalid action' });
        }

        const { cognitoSub, email, firstName, lastName, accountType, organizationId } = data;
        
        // Validate required fields
        if (!cognitoSub || !email) {
          return res.status(400).json({ error: 'Missing required fields: cognitoSub, email' });
        }

        // Create user record
        const userId = uuidv4();
        const user = {
          id: userId,
          cognitoSub,
          email,
          firstName: firstName || '',
          lastName: lastName || '',
          accountType: accountType || 'INDIVIDUAL',
          organizationId,
          role: 'OWNER', // Default role for new users
          isActive: true,
          createdAt: new Date().toISOString(),
          activatedAt: new Date().toISOString()
        };

        this.users.set(cognitoSub, user);
        
        console.log('User activated successfully:', user);
        
        res.status(200).json({
          success: true,
          message: 'User activated successfully',
          userId: userId,
          data: {
            id: userId,
            email: email,
            isActive: true
          }
        });
        
      } catch (error) {
        console.error('Error activating user:', error);
        res.status(500).json({ error: 'Internal server error', details: error.message });
      }
    });

    // Get user by Cognito sub (for role lookup in pre-token Lambda)
    this.app.get('/api/v1/internal/user/:cognitoSub', (req, res) => {
      try {
        const { cognitoSub } = req.params;
        const user = this.users.get(cognitoSub);
        
        if (!user) {
          return res.status(404).json({ error: 'User not found' });
        }

        res.json({
          success: true,
          data: {
            id: user.id,
            cognitoSub: user.cognitoSub,
            email: user.email,
            role: user.role,
            accountType: user.accountType,
            organizationId: user.organizationId,
            isActive: user.isActive
          }
        });
        
      } catch (error) {
        console.error('Error getting user:', error);
        res.status(500).json({ error: 'Internal server error', details: error.message });
      }
    });

    // Update user role (for testing role changes)
    this.app.patch('/api/v1/internal/user/:cognitoSub/role', (req, res) => {
      try {
        const { cognitoSub } = req.params;
        const { role } = req.body;
        
        const user = this.users.get(cognitoSub);
        if (!user) {
          return res.status(404).json({ error: 'User not found' });
        }

        user.role = role;
        user.updatedAt = new Date().toISOString();
        
        res.json({
          success: true,
          message: 'User role updated successfully',
          data: { role: user.role }
        });
        
      } catch (error) {
        console.error('Error updating user role:', error);
        res.status(500).json({ error: 'Internal server error', details: error.message });
      }
    });

    // Test endpoints for verification
    this.app.get('/api/test/users', (req, res) => {
      res.json({
        users: Array.from(this.users.values()),
        count: this.users.size
      });
    });

    this.app.get('/api/test/requests', (req, res) => {
      res.json({
        requests: this.requests,
        count: this.requests.length
      });
    });

    this.app.delete('/api/test/reset', (req, res) => {
      this.users.clear();
      this.requests.length = 0;
      res.json({ message: 'Server state reset successfully' });
    });

    // Error handling
    this.app.use((error, req, res, next) => {
      console.error('Server error:', error);
      res.status(500).json({ error: 'Internal server error', details: error.message });
    });

    // 404 handler
    this.app.use('*', (req, res) => {
      res.status(404).json({ error: 'Endpoint not found' });
    });
  }

  start() {
    return new Promise((resolve) => {
      this.server = this.app.listen(this.port, () => {
        console.log(`Mock API server running on port ${this.port}`);
        resolve();
      });
    });
  }

  stop() {
    return new Promise((resolve) => {
      if (this.server) {
        this.server.close(() => {
          console.log('Mock API server stopped');
          resolve();
        });
      } else {
        resolve();
      }
    });
  }

  // Helper methods for testing
  getUser(cognitoSub) {
    return this.users.get(cognitoSub);
  }

  getUsers() {
    return Array.from(this.users.values());
  }

  getRequests() {
    return this.requests;
  }

  reset() {
    this.users.clear();
    this.requests.length = 0;
  }
}

// Allow running as standalone server or importing as module
if (require.main === module) {
  const server = new MockApiServer();
  server.start().then(() => {
    console.log('Mock API server started successfully');
  });

  // Graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\nShutting down Mock API server...');
    await server.stop();
    process.exit(0);
  });
}

module.exports = MockApiServer;