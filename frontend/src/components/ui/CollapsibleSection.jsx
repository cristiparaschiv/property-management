import React, { useState } from 'react';
import { DownOutlined } from '@ant-design/icons';

/**
 * CollapsibleSection - A section that can be expanded/collapsed
 * Persists state in localStorage if storageKey is provided
 */
const CollapsibleSection = ({
  title,
  icon,
  children,
  defaultCollapsed = false,
  storageKey = null,
  className = '',
}) => {
  // Get initial state from localStorage if storageKey provided
  const getInitialState = () => {
    if (storageKey) {
      const stored = localStorage.getItem(`collapsible-${storageKey}`);
      if (stored !== null) {
        return stored === 'true';
      }
    }
    return defaultCollapsed;
  };

  const [isCollapsed, setIsCollapsed] = useState(getInitialState);

  const toggleCollapse = () => {
    const newState = !isCollapsed;
    setIsCollapsed(newState);
    if (storageKey) {
      localStorage.setItem(`collapsible-${storageKey}`, newState.toString());
    }
  };

  return (
    <div className={`pm-section-collapsible ${isCollapsed ? 'pm-section-collapsible--collapsed' : ''} ${className}`}>
      <div
        className="pm-section-collapsible__header"
        onClick={toggleCollapse}
        role="button"
        tabIndex={0}
        onKeyDown={(e) => e.key === 'Enter' && toggleCollapse()}
        aria-expanded={!isCollapsed}
      >
        <h3 className="pm-section-collapsible__title">
          {icon && <span className="pm-section-collapsible__title-icon">{icon}</span>}
          {title}
        </h3>
        <DownOutlined className="pm-section-collapsible__icon" />
      </div>
      <div className="pm-section-collapsible__content">
        {children}
      </div>
    </div>
  );
};

export default CollapsibleSection;
