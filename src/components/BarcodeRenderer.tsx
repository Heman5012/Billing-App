import React, { useEffect, useRef } from 'react';
import JsBarcode from 'jsbarcode';

interface BarcodeRendererProps {
  value: string;
  width?: number;
  height?: number;
  displayValue?: boolean;
  fontSize?: number;
  className?: string;
}

export const BarcodeRenderer: React.FC<BarcodeRendererProps> = ({
  value,
  width = 1.8,
  height = 50,
  displayValue = true,
  fontSize = 12,
  className = '',
}) => {
  const svgRef = useRef<SVGSVGElement | null>(null);

  useEffect(() => {
    if (!svgRef.current || !value) return;

    const clean = value.trim();
    if (!clean) return;

    try {
      // Try EAN13 if exactly 13 numeric digits
      if (/^\d{13}$/.test(clean)) {
        try {
          JsBarcode(svgRef.current, clean, {
            format: 'EAN13',
            width,
            height,
            displayValue,
            fontSize,
            margin: 4,
            background: 'transparent',
            lineColor: '#0f172a',
          });
          return;
        } catch {
          // Fall through to CODE128 if EAN checksum fails
        }
      }

      // Default robust CODE128 format
      JsBarcode(svgRef.current, clean, {
        format: 'CODE128',
        width,
        height,
        displayValue,
        fontSize,
        margin: 4,
        background: 'transparent',
        lineColor: '#0f172a',
      });
    } catch (err) {
      console.warn('JsBarcode render error for:', clean, err);
    }
  }, [value, width, height, displayValue, fontSize]);

  if (!value) return null;

  return (
    <div className={`inline-flex items-center justify-center ${className}`}>
      <svg ref={svgRef} className="max-w-full" />
    </div>
  );
};
