import React from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';
import { motion } from 'framer-motion';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'primary', size = 'md', ...props }, ref) => {
    const variants = {
      primary: 'bg-fm-teal text-fm-dark hover:bg-opacity-90',
      secondary: 'bg-fm-surface text-fm-light hover:bg-opacity-80',
      danger: 'bg-fm-danger text-white hover:bg-opacity-90',
      outline: 'border border-fm-teal text-fm-teal hover:bg-fm-teal/10',
      ghost: 'text-fm-light hover:bg-fm-light/10',
    };

    const sizes = {
      sm: 'px-3 py-1.5 text-sm',
      md: 'px-4 py-2',
      lg: 'px-6 py-3 text-lg',
    };

    return (
      <motion.button
        ref={ref}
        whileTap={{ scale: 0.98 }}
        className={cn(
          'rounded-md font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-fm-teal/50 disabled:opacity-50 disabled:cursor-not-allowed',
          variants[variant],
          sizes[size],
          className
        )}
        {...props}
      />
    );
  }
);

export const Card = ({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) => (
  <div className={cn('bg-fm-surface rounded-lg shadow-lg p-4 border border-white/5', className)} {...props}>
    {children}
  </div>
);

export const Input = React.forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        'bg-fm-dark/50 border border-white/10 rounded px-3 py-2 text-fm-light focus:border-fm-teal focus:ring-1 focus:ring-fm-teal outline-none transition-all',
        className
      )}
      {...props}
    />
  )
);

export const Select = React.forwardRef<HTMLSelectElement, React.SelectHTMLAttributes<HTMLSelectElement>>(
  ({ className, ...props }, ref) => (
    <select
      ref={ref}
      className={cn(
        'bg-fm-dark/50 border border-white/10 rounded px-3 py-2 text-fm-light focus:border-fm-teal focus:ring-1 focus:ring-fm-teal outline-none transition-all',
        className
      )}
      {...props}
    />
  )
);

export const Badge = ({ children, variant = 'default', className }: { children: React.ReactNode, variant?: 'default' | 'success' | 'warning' | 'danger', className?: string }) => {
  const variants = {
    default: 'bg-white/10 text-white',
    success: 'bg-fm-success/20 text-fm-success border border-fm-success/20',
    warning: 'bg-yellow-500/20 text-yellow-400 border border-yellow-500/20',
    danger: 'bg-fm-danger/20 text-fm-danger border border-fm-danger/20',
  };
  
  return (
    <span className={cn('px-2 py-0.5 rounded text-xs font-medium', variants[variant], className)}>
      {children}
    </span>
  );
};

