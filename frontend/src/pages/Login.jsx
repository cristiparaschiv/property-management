import React, { useState } from 'react';
import { Form, Input, Button, Card, message, Alert } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { authService } from '../services/authService';
import useAuthStore from '../stores/authStore';

const Login = () => {
  const navigate = useNavigate();
  const { setAuth } = useAuthStore();
  const [form] = Form.useForm();
  const [errorMessage, setErrorMessage] = useState(null);

  /**
   * Get appropriate error message based on error type and status code
   */
  const getErrorMessage = (error) => {
    // Network error (no response from server)
    if (!error.response) {
      return 'Eroare de conexiune. Verificați conexiunea la internet.';
    }

    const status = error.response.status;
    const serverMessage = error.response.data?.error;

    // Invalid credentials (401)
    if (status === 401) {
      return 'Nume de utilizator sau parolă incorectă';
    }

    // Server error (500)
    if (status >= 500) {
      return 'Eroare de server. Încercați din nou.';
    }

    // Other errors with server message
    if (serverMessage) {
      return serverMessage;
    }

    // Generic fallback
    return 'Eroare la autentificare. Încercați din nou.';
  };

  /**
   * Clear error message when user starts typing or submitting
   */
  const clearError = () => {
    if (errorMessage) {
      setErrorMessage(null);
    }
  };

  const loginMutation = useMutation({
    mutationFn: ({ username, password }) => authService.login(username, password),
    onSuccess: (data) => {
      if (data.success) {
        // Clear any existing errors
        setErrorMessage(null);
        // Store JWT token, user info, and CSRF token
        setAuth(data.data.token, data.data.user, data.data.csrf_token);
        message.success('Autentificare reușită!');
        navigate('/');
      } else {
        // API returned success: false
        const errorMsg = data.error || 'Autentificare eșuată';
        setErrorMessage(errorMsg);
        message.error(errorMsg);
      }
    },
    onError: (error) => {
      const errorMsg = getErrorMessage(error);
      setErrorMessage(errorMsg);
      message.error(errorMsg);
    },
  });

  const onFinish = (values) => {
    // Clear any existing error before submitting
    clearError();
    loginMutation.mutate(values);
  };

  return (
    <div
      style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      }}
    >
      <Card
        style={{
          width: 400,
          boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)',
        }}
      >
        <div style={{ textAlign: 'center', marginBottom: 24 }}>
          <h1 style={{ fontSize: 28, marginBottom: 8 }}>PropertyManager</h1>
          <p style={{ color: '#888' }}>Sistem de Management Proprietăți</p>
        </div>

        {errorMessage && (
          <Alert
            message={errorMessage}
            type="error"
            showIcon
            closable
            onClose={clearError}
            style={{ marginBottom: 16 }}
            data-testid="login-error-alert"
          />
        )}

        <Form
          form={form}
          name="login"
          onFinish={onFinish}
          onFieldsChange={clearError}
          autoComplete="off"
          size="large"
        >
          <Form.Item
            name="username"
            rules={[
              {
                required: true,
                message: 'Vă rugăm introduceți numele de utilizator!',
              },
            ]}
          >
            <Input
              prefix={<UserOutlined />}
              placeholder="Nume utilizator"
            />
          </Form.Item>

          <Form.Item
            name="password"
            rules={[
              {
                required: true,
                message: 'Vă rugăm introduceți parola!',
              },
            ]}
          >
            <Input.Password
              prefix={<LockOutlined />}
              placeholder="Parolă"
            />
          </Form.Item>

          <Form.Item>
            <Button
              type="primary"
              htmlType="submit"
              block
              loading={loginMutation.isPending}
            >
              Autentificare
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
};

export default Login;
