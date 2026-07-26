import { Component } from 'react';
import { Result, Button, Typography } from 'antd';
import { ReloadOutlined } from '@ant-design/icons';

const { Paragraph, Text } = Typography;

/**
 * Catches render/lifecycle errors in its subtree and shows a recoverable
 * fallback instead of unmounting the whole app to a blank screen.
 *
 * Pass `resetKey` (e.g. the current route path) so the boundary clears itself
 * when the user navigates away — a crashed page must not trap the whole app.
 */
class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidUpdate(prevProps) {
    // Reset when the reset key changes (e.g. route navigation).
    if (this.state.hasError && prevProps.resetKey !== this.props.resetKey) {
      this.setState({ hasError: false, error: null });
    }
  }

  componentDidCatch(error, info) {
    console.error('[ErrorBoundary]', error, info?.componentStack);
  }

  handleReload = () => {
    window.location.reload();
  };

  handleReset = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (!this.state.hasError) {
      return this.props.children;
    }

    const fullScreen = this.props.fullScreen;
    const content = (
      <Result
        status="error"
        title="A apărut o eroare neașteptată"
        subTitle="Pagina nu a putut fi afișată. Datele tale sunt în siguranță — reîncarcă sau încearcă din nou."
        extra={[
          <Button
            type="primary"
            icon={<ReloadOutlined />}
            key="reload"
            onClick={this.handleReload}
          >
            Reîncarcă pagina
          </Button>,
          <Button key="retry" onClick={this.handleReset}>
            Încearcă din nou
          </Button>,
        ]}
      >
        {import.meta.env.DEV && this.state.error && (
          <Paragraph>
            <Text type="danger" code style={{ whiteSpace: 'pre-wrap' }}>
              {String(this.state.error?.message || this.state.error)}
            </Text>
          </Paragraph>
        )}
      </Result>
    );

    if (fullScreen) {
      return (
        <div
          style={{
            minHeight: '100vh',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {content}
        </div>
      );
    }
    return content;
  }
}

export default ErrorBoundary;
