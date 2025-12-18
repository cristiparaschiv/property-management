import React, { useEffect, useState, useRef } from 'react';

/**
 * AnimatedCounter - Smoothly animates number changes
 * @param {number} value - Target value to animate to
 * @param {number} duration - Animation duration in milliseconds
 * @param {function} formatter - Optional formatter function for the display value
 * @param {number} decimals - Number of decimal places
 */
const AnimatedCounter = ({
  value,
  duration = 1000,
  formatter,
  decimals = 0,
}) => {
  const [displayValue, setDisplayValue] = useState(0);
  const startTimeRef = useRef(null);
  const startValueRef = useRef(0);
  const animationRef = useRef(null);

  useEffect(() => {
    // Cancel any ongoing animation
    if (animationRef.current) {
      cancelAnimationFrame(animationRef.current);
    }

    const targetValue = typeof value === 'number' ? value : 0;

    const animate = (timestamp) => {
      if (!startTimeRef.current) {
        startTimeRef.current = timestamp;
        startValueRef.current = displayValue;
      }

      const elapsed = timestamp - startTimeRef.current;
      const progress = Math.min(elapsed / duration, 1);

      // Ease-out cubic for smooth deceleration
      const easeOut = 1 - Math.pow(1 - progress, 3);
      const current = startValueRef.current + (targetValue - startValueRef.current) * easeOut;

      setDisplayValue(current);

      if (progress < 1) {
        animationRef.current = requestAnimationFrame(animate);
      } else {
        setDisplayValue(targetValue);
        startTimeRef.current = null;
        animationRef.current = null;
      }
    };

    animationRef.current = requestAnimationFrame(animate);

    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [value, duration]);

  // Format the display value
  const formattedValue = () => {
    const roundedValue = decimals > 0
      ? Math.round(displayValue * Math.pow(10, decimals)) / Math.pow(10, decimals)
      : Math.round(displayValue);

    if (formatter) {
      return formatter(roundedValue);
    }

    // Default formatting with thousand separators
    return roundedValue.toLocaleString('ro-RO', {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals,
    });
  };

  return <span>{formattedValue()}</span>;
};

export default AnimatedCounter;
