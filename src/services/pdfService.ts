import { Invoice, BusinessProfile } from '../types';

export class PdfService {
  public static printInvoice(invoice: Invoice, business: BusinessProfile) {
    const printWindow = window.open('', '_blank', 'width=800,height=900');
    if (!printWindow) {
      window.print();
      return;
    }

    const itemsHtml = invoice.items
      .map(
        (item) => `
        <tr>
          <td style="padding: 8px 4px; border-bottom: 1px solid #e2e8f0; font-size: 13px;">${item.name}</td>
          <td style="padding: 8px 4px; border-bottom: 1px solid #e2e8f0; text-align: right; font-size: 13px;">${business.currency}${item.unitPrice.toFixed(2)}</td>
          <td style="padding: 8px 4px; border-bottom: 1px solid #e2e8f0; text-align: center; font-size: 13px;">${item.quantity}</td>
          <td style="padding: 8px 4px; border-bottom: 1px solid #e2e8f0; text-align: center; font-size: 13px;">${item.taxRate}%</td>
          <td style="padding: 8px 4px; border-bottom: 1px solid #e2e8f0; text-align: right; font-weight: bold; font-size: 13px;">${business.currency}${item.lineTotal.toFixed(2)}</td>
        </tr>
      `
      )
      .join('');

    const taxRowsHtml = Object.entries(invoice.taxBreakdown)
      .map(
        ([rate, amt]) => `
        <div style="display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 3px; color: #475569;">
          <span>Tax (${rate}):</span>
          <span>${business.currency}${amt.toFixed(2)}</span>
        </div>
      `
      )
      .join('');

    const formattedDate = new Date(invoice.createdAt).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });

    const html = `
      <!DOCTYPE html>
      <html>
        <head>
          <title>Invoice ${invoice.invoiceNumber} - ${business.businessName}</title>
          <style>
            @page { size: A4; margin: 15mm; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
              color: #0f172a;
              margin: 0;
              padding: 20px;
              background: #fff;
            }
            .header-badge {
              display: inline-block;
              background: #10b981;
              color: #fff;
              font-weight: bold;
              padding: 4px 8px;
              border-radius: 4px;
              font-size: 14px;
            }
            .demo-badge {
              display: inline-block;
              background: #fef3c7;
              border: 1px solid #f59e0b;
              color: #b45309;
              font-size: 11px;
              font-weight: bold;
              padding: 3px 6px;
              border-radius: 4px;
            }
            table { width: 100%; border-collapse: collapse; margin-top: 15px; margin-bottom: 15px; }
            th { background: #f8fafc; font-size: 12px; font-weight: bold; padding: 8px 4px; text-align: left; border-bottom: 2px solid #cbd5e1; }
            .totals-container { margin-left: auto; width: 280px; }
          </style>
        </head>
        <body>
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 20px;">
            <div>
              <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 6px;">
                <span class="header-badge">BillWave</span>
                <strong style="font-size: 16px;">TAX INVOICE</strong>
              </div>
              <h2 style="margin: 0; font-size: 20px; color: #0f172a;">${business.businessName}</h2>
              <div style="font-size: 12px; color: #64748b; margin-top: 4px;">
                ${business.address ? `<div>${business.address}</div>` : ''}
                ${business.phone ? `<div>Phone: ${business.phone}</div>` : ''}
              </div>
            </div>
            <div style="text-align: right;">
              <div class="demo-badge" style="margin-bottom: 6px;">SIMULATED / DEMO</div>
              <div style="font-size: 15px; font-weight: bold; color: #0f172a;">${invoice.invoiceNumber}</div>
              <div style="font-size: 12px; color: #64748b; margin-top: 2px;">${formattedDate}</div>
              <div style="font-size: 12px; color: #15803d; font-weight: bold; margin-top: 2px;">
                ${invoice.paymentMethod} • ${invoice.paymentStatus.toUpperCase()}
              </div>
            </div>
          </div>

          ${
            invoice.customer.name || invoice.customer.phone
              ? `
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 8px 12px; margin-bottom: 15px; font-size: 12px;">
              <strong>Billed To:</strong> ${invoice.customer.name || 'Customer'}
              ${invoice.customer.phone ? ` &nbsp;|&nbsp; <strong>Phone:</strong> ${invoice.customer.phone}` : ''}
            </div>
          `
              : ''
          }

          <table>
            <thead>
              <tr>
                <th style="width: 40%;">Item Description</th>
                <th style="text-align: right; width: 18%;">Unit Price</th>
                <th style="text-align: center; width: 10%;">Qty</th>
                <th style="text-align: center; width: 12%;">Tax</th>
                <th style="text-align: right; width: 20%;">Total</th>
              </tr>
            </thead>
            <tbody>
              ${itemsHtml}
            </tbody>
          </table>

          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-top: 15px;">
            <div style="font-size: 11px; color: #64748b; max-width: 340px;">
              ${invoice.notes ? `<p><strong>Note:</strong> ${invoice.notes}</p>` : ''}
              <p>Thank you for shopping with us! This receipt was generated with BillWave POS.</p>
              <p style="font-size: 10px; color: #94a3b8;">Verification Token: ${invoice.shareToken}</p>
            </div>
            <div class="totals-container">
              <div style="display: flex; justify-content: space-between; font-size: 13px; margin-bottom: 4px;">
                <span>Subtotal:</span>
                <span>${business.currency}${invoice.subtotal.toFixed(2)}</span>
              </div>
              ${
                invoice.overallDiscountAmount > 0
                  ? `
                <div style="display: flex; justify-content: space-between; font-size: 13px; margin-bottom: 4px; color: #dc2626;">
                  <span>Discount (${invoice.overallDiscountPercent.toFixed(0)}%):</span>
                  <span>-${business.currency}${invoice.overallDiscountAmount.toFixed(2)}</span>
                </div>
              `
                  : ''
              }
              <div style="display: flex; justify-content: space-between; font-size: 13px; margin-bottom: 4px;">
                <span>Taxable Amount:</span>
                <span>${business.currency}${invoice.taxableAmount.toFixed(2)}</span>
              </div>
              ${taxRowsHtml}
              <div style="border-top: 2px solid #0f172a; margin-top: 8px; padding-top: 8px; display: flex; justify-content: space-between; font-size: 18px; font-weight: 800; color: #0f172a;">
                <span>Grand Total:</span>
                <span style="color: #10b981;">${business.currency}${invoice.total.toFixed(2)}</span>
              </div>
            </div>
          </div>
        </body>
      </html>
    `;

    printWindow.document.open();
    printWindow.document.write(html);
    printWindow.document.close();
    setTimeout(() => {
      printWindow.focus();
      printWindow.print();
    }, 400);
  }

  public static async shareInvoice(invoice: Invoice, business: BusinessProfile) {
    const url = `${window.location.origin}/?token=${invoice.shareToken}`;
    const shareData = {
      title: `Invoice ${invoice.invoiceNumber} - ${business.businessName}`,
      text: `Tax Invoice ${invoice.invoiceNumber} for ${business.currency}${invoice.total.toFixed(2)} from ${business.businessName}`,
      url: url,
    };

    if (navigator.share && navigator.canShare && navigator.canShare(shareData)) {
      try {
        await navigator.share(shareData);
        return;
      } catch (_) {}
    }

    try {
      await navigator.clipboard.writeText(url);
      alert(`Invoice share link copied to clipboard!\n${url}`);
    } catch (_) {
      alert(`Invoice Link: ${url}`);
    }
  }
}

export function printInvoiceReceipt(invoice: Invoice, business?: BusinessProfile) {
  const profile: BusinessProfile = business || invoice.business || {
    businessName: 'BillWave Supermarket',
    address: 'High Street, Retail Hub, Bangalore',
    phone: '+91 98765 43210',
    currency: '₹',
    configuredTaxRates: [0, 5, 12, 18, 28],
  };
  PdfService.printInvoice(invoice, profile);
}
