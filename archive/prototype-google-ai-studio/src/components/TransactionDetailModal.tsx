import React, { useState, useRef } from 'react';
import {
  X,
  Calendar,
  Tag,
  User,
  Paperclip,
  History,
  CheckCircle2,
  AlertTriangle,
  FileEdit,
  Building,
  Save,
  Trash2,
  ChevronRight,
  Sparkles,
  MessageSquare,
  Send,
  Upload,
  Check,
  XCircle,
  Clock,
  Shield,
  CornerDownRight,
  AtSign,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { Transaction, TransactionStatus, ProfileEntity, CollaborationRole } from '../types';
import { formatPeso } from '../utils/format';
import { STATUS_BADGE_CONFIG, PROFILE_OPTIONS } from '../data/categories';
import { checkMemberAccess } from '../utils/collaborationEngine';

interface TransactionDetailModalProps {
  transaction: Transaction | null;
  isOpen: boolean;
  onClose: () => void;
}

export const TransactionDetailModal: React.FC<TransactionDetailModalProps> = ({
  transaction,
  isOpen,
  onClose,
}) => {
  const {
    accounts,
    updateTransaction,
    deleteTransaction,
    categories,
    activeMember,
    spaces,
    members,
    addTransactionComment,
    approveTransaction,
    rejectTransaction,
    attachReceiptToTransaction,
    removeReceiptFromTransaction,
  } = useFinancial();

  if (!isOpen || !transaction) return null;

  const [isEditing, setIsEditing] = useState(false);
  const [amount, setAmount] = useState(transaction.amount.toString());
  const [merchant, setMerchant] = useState(transaction.merchant || '');
  const [category, setCategory] = useState(transaction.category);
  const [subcategory, setSubcategory] = useState(transaction.subcategory || '');
  const [profile, setProfile] = useState<ProfileEntity>(transaction.profile || 'personal');
  const [person, setPerson] = useState(transaction.person || '');
  const [status, setStatus] = useState<TransactionStatus>(transaction.status || 'confirmed');
  const [date, setDate] = useState(transaction.date);
  const [note, setNote] = useState(transaction.note || '');
  const [tagInput, setTagInput] = useState((transaction.tags || []).join(', '));
  const [auditNote, setAuditNote] = useState('');
  const [showAttachmentViewer, setShowAttachmentViewer] = useState(false);

  // Collaboration State
  const [commentText, setCommentText] = useState('');
  const [replyingToId, setReplyingToId] = useState<string | null>(null);
  const [rejectionNote, setRejectionNote] = useState('');
  const [isRejecting, setIsRejecting] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const activePermissions = checkMemberAccess(activeMember);
  const sourceAccount = accounts.find((a) => a.id === transaction.accountId);
  const destAccount = accounts.find((a) => a.id === transaction.toAccountId);
  const space = spaces.find((s) => s.id === transaction.spaceId);

  const selectedCategoryObj = categories.find(
    (c) => c.name.toLowerCase() === category.toLowerCase()
  );
  const subcategoriesList = selectedCategoryObj?.subcategories || [];

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    const newAmount = parseFloat(amount.replace(/,/g, ''));
    if (isNaN(newAmount) || newAmount <= 0) return;

    const tagsArray = tagInput
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
      .map((t) => (t.startsWith('#') ? t : `#${t}`));

    updateTransaction(
      transaction.id,
      {
        amount: newAmount,
        merchant: merchant.trim() || undefined,
        category,
        subcategory: subcategory || undefined,
        profile,
        person: person.trim() || undefined,
        status,
        date,
        note: note.trim() || undefined,
        tags: tagsArray,
      },
      auditNote.trim() || 'Manual journal adjustment and verification'
    );

    setIsEditing(false);
    setAuditNote('');
  };

  const handleDelete = () => {
    if (window.confirm('Delete this ledger entry? This will reverse all corresponding account balances.')) {
      deleteTransaction(transaction.id);
      onClose();
    }
  };

  const handleAddComment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!commentText.trim()) return;

    // Detect @mentions
    const mentions = commentText
      .split(' ')
      .filter((w) => w.startsWith('@'))
      .map((w) => w.replace(/[^a-zA-Z0-9]/g, ''))
      .filter((w) => w.length > 0);

    addTransactionComment(
      transaction.id,
      commentText.trim(),
      replyingToId || undefined,
      mentions.length > 0 ? mentions : undefined
    );

    setCommentText('');
    setReplyingToId(null);
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const dataUrl = event.target?.result as string;
      if (dataUrl) {
        attachReceiptToTransaction(transaction.id, dataUrl, file.name);
      }
    };
    reader.readAsDataURL(file);
  };

  const handleApprove = () => {
    approveTransaction(transaction.id, 'Approved via transaction audit panel');
  };

  const handleReject = () => {
    if (!rejectionNote.trim()) return;
    rejectTransaction(transaction.id, rejectionNote.trim());
    setIsRejecting(false);
    setRejectionNote('');
  };

  const badgeStyle = STATUS_BADGE_CONFIG[transaction.status || 'confirmed'];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4">
      {/* Backdrop */}
      <div className="fixed inset-0 bg-black/60 backdrop-blur-xs" onClick={onClose} />

      {/* Modal Container */}
      <div className="relative w-full max-w-lg bg-white dark:bg-[#27201A] rounded-3xl shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[90vh] flex flex-col overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-[#F3DFCD] dark:border-[#383029]">
          <div className="flex items-center gap-2 flex-wrap">
            <span
              className={`px-2.5 py-1 rounded-full text-xs font-bold border uppercase tracking-wider ${badgeStyle.bg} ${badgeStyle.text} ${badgeStyle.border}`}
            >
              {badgeStyle.label}
            </span>

            {space && (
              <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] border border-[#F3DFCD] dark:border-[#383029] flex items-center gap-1">
                <span>{space.emoji}</span>
                <span>{space.name}</span>
              </span>
            )}

            {transaction.isAdjustment && (
              <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/20 text-amber-700 dark:text-amber-300 border border-amber-500/30">
                Reconciliation Entry
              </span>
            )}
          </div>

          <div className="flex items-center gap-1.5">
            {!isEditing && activePermissions.canEditTransactions && (
              <button
                type="button"
                onClick={() => setIsEditing(true)}
                className="px-3 py-1 text-xs font-semibold rounded-lg bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] hover:opacity-90 flex items-center gap-1 cursor-pointer"
              >
                <FileEdit size={13} />
                <span>Edit</span>
              </button>
            )}
            <button
              type="button"
              onClick={onClose}
              className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
            >
              <X size={20} />
            </button>
          </div>
        </div>

        {/* Modal Body */}
        <div className="overflow-y-auto p-5 space-y-4">
          {!isEditing ? (
            <>
              {/* Approval Banner if transaction requires approval or has approval info */}
              {transaction.approval && (
                <div
                  className={`p-3 rounded-2xl border text-xs flex flex-col gap-2 ${
                    transaction.approval.status === 'pending_approval'
                      ? 'bg-amber-500/10 border-amber-500/30 text-amber-900 dark:text-amber-200'
                      : transaction.approval.status === 'approved'
                      ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-900 dark:text-emerald-200'
                      : 'bg-rose-500/10 border-rose-500/30 text-rose-900 dark:text-rose-200'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-1.5 font-extrabold">
                      {transaction.approval.status === 'pending_approval' ? (
                        <>
                          <Clock size={15} className="text-amber-600 dark:text-amber-400" />
                          <span>Pending Manager Review</span>
                        </>
                      ) : transaction.approval.status === 'approved' ? (
                        <>
                          <CheckCircle2 size={15} className="text-emerald-600 dark:text-emerald-400" />
                          <span>Approved by {transaction.approval.reviewedBy}</span>
                        </>
                      ) : (
                        <>
                          <XCircle size={15} className="text-rose-600 dark:text-rose-400" />
                          <span>Rejected by {transaction.approval.reviewedBy}</span>
                        </>
                      )}
                    </div>
                    <span className="text-[10px] font-bold uppercase">
                      {transaction.approval.status.replace('_', ' ')}
                    </span>
                  </div>

                  {transaction.approval.reason && (
                    <p className="text-[11px] italic">
                      "{transaction.approval.reason}"
                    </p>
                  )}

                  {/* Actions for Authorized Reviewers */}
                  {transaction.approval.status === 'pending_approval' && activePermissions.canApproveTransactions && (
                    <div className="flex items-center gap-2 pt-1 border-t border-amber-500/20">
                      {!isRejecting ? (
                        <>
                          <button
                            type="button"
                            onClick={() => setIsRejecting(true)}
                            className="flex-1 py-1.5 rounded-xl border border-rose-500/40 text-rose-700 dark:text-rose-300 font-bold text-xs hover:bg-rose-500/10 cursor-pointer"
                          >
                            Reject Entry
                          </button>
                          <button
                            type="button"
                            onClick={handleApprove}
                            className="flex-1 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs cursor-pointer flex items-center justify-center gap-1"
                          >
                            <Check size={13} />
                            <span>Approve Entry</span>
                          </button>
                        </>
                      ) : (
                        <div className="w-full flex flex-col gap-2">
                          <input
                            type="text"
                            value={rejectionNote}
                            onChange={(e) => setRejectionNote(e.target.value)}
                            placeholder="Reason for rejection (required)"
                            className="w-full px-3 py-1.5 rounded-xl bg-white dark:bg-[#14100D] border border-rose-500/40 text-xs text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                          />
                          <div className="flex gap-2">
                            <button
                              type="button"
                              onClick={() => setIsRejecting(false)}
                              className="flex-1 py-1 rounded-lg border text-xs"
                            >
                              Cancel
                            </button>
                            <button
                              type="button"
                              disabled={!rejectionNote.trim()}
                              onClick={handleReject}
                              className="flex-1 py-1 rounded-lg bg-rose-600 text-white text-xs font-bold disabled:opacity-50"
                            >
                              Confirm Reject
                            </button>
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}

              {/* Main Amount & Description */}
              <div className="flex flex-col items-center justify-center py-2 text-center border-b border-[#F3DFCD]/60 dark:border-[#383029]/60 pb-4">
                <span className="text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] capitalize">
                  {transaction.type} Ledger Entry
                </span>
                <div
                  className={`text-3xl sm:text-4xl font-extrabold tracking-tight my-1 tabular-nums ${
                    transaction.type === 'income'
                      ? 'text-[#16643F] dark:text-[#5FCB8E]'
                      : transaction.type === 'expense'
                      ? 'text-[#15120F] dark:text-[#F6EFE8]'
                      : 'text-[#B03C09] dark:text-[#FF9A52]'
                  }`}
                >
                  {transaction.type === 'income' ? '+' : transaction.type === 'expense' ? '-' : ''}
                  {formatPeso(transaction.amount)}
                </div>
                {transaction.originalAmount && transaction.originalAmount !== transaction.amount && (
                  <div className="text-xs font-medium text-[#6B6156] dark:text-[#AC9E92]">
                    Original value: <span className="line-through">{formatPeso(transaction.originalAmount)}</span> (Corrected)
                  </div>
                )}
                <h3 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8] mt-1">
                  {transaction.merchant || transaction.category}
                </h3>
              </div>

              {/* Attributes Grid */}
              <div className="grid grid-cols-2 gap-3 text-xs">
                {/* Source Account */}
                <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                  <span className="text-[#6B6156] dark:text-[#AC9E92] block font-medium mb-1">
                    {transaction.type === 'transfer' ? 'Source Account' : 'Account'}
                  </span>
                  <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
                    <span className="text-[10px] px-1 py-0.5 rounded bg-amber-500/20 text-amber-700 dark:text-amber-300 font-bold">
                      {sourceAccount?.monogram || 'ACC'}
                    </span>
                    <span className="truncate">{sourceAccount?.name || 'External'}</span>
                  </div>
                </div>

                {/* Destination Account or Entity Profile */}
                <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                  <span className="text-[#6B6156] dark:text-[#AC9E92] block font-medium mb-1">
                    {transaction.type === 'transfer' ? 'Destination Account' : 'Entity / Profile'}
                  </span>
                  {transaction.type === 'transfer' ? (
                    <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
                      <span className="text-[10px] px-1 py-0.5 rounded bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 font-bold">
                        {destAccount?.monogram || 'ACC'}
                      </span>
                      <span className="truncate">{destAccount?.name || 'Destination'}</span>
                    </div>
                  ) : (
                    <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] capitalize flex items-center gap-1">
                      <Building size={12} className="text-[#B03C09] dark:text-[#FF9A52]" />
                      <span>{transaction.profile || 'Personal'}</span>
                    </div>
                  )}
                </div>

                {/* Category & Subcategory */}
                <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                  <span className="text-[#6B6156] dark:text-[#AC9E92] block font-medium mb-1">
                    Category
                  </span>
                  <div className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    {transaction.category}
                  </div>
                  {transaction.subcategory && (
                    <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] truncate mt-0.5">
                      {transaction.subcategory}
                    </div>
                  )}
                </div>

                {/* Date & Logged By */}
                <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                  <span className="text-[#6B6156] dark:text-[#AC9E92] block font-medium mb-1">
                    Date &amp; Author
                  </span>
                  <div className="font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1">
                    <Calendar size={12} />
                    <span>{transaction.date}</span>
                  </div>
                  <div className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-0.5 truncate">
                    By: {transaction.collaboratorName || 'Account Owner'}
                  </div>
                </div>
              </div>

              {/* Person Involved & Tags */}
              <div className="space-y-2 text-xs">
                {transaction.person && (
                  <div className="flex items-center gap-2 p-2.5 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F3DFCD]/60 dark:border-[#383029]/60">
                    <User size={14} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0" />
                    <span className="text-[#6B6156] dark:text-[#AC9E92]">Person involved:</span>
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      {transaction.person}
                    </span>
                  </div>
                )}

                {transaction.tags && transaction.tags.length > 0 && (
                  <div className="flex flex-wrap items-center gap-1.5 pt-1">
                    <Tag size={13} className="text-[#6B6156] dark:text-[#AC9E92]" />
                    {transaction.tags.map((tag, idx) => (
                      <span
                        key={idx}
                        className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52]"
                      >
                        {tag}
                      </span>
                    ))}
                  </div>
                )}

                {transaction.note && (
                  <div className="p-3 rounded-2xl bg-stone-50 dark:bg-[#1E1813] border border-[#F3DFCD] dark:border-[#383029] text-xs">
                    <span className="text-[10px] uppercase font-bold text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                      Notes
                    </span>
                    <p className="text-[#15120F] dark:text-[#F6EFE8] leading-relaxed">
                      {transaction.note}
                    </p>
                  </div>
                )}
              </div>

              {/* Receipt / Attachment Section with Direct Upload */}
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-1.5 text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    <Paperclip size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <span>Official Receipt &amp; Documentation</span>
                  </div>

                  <div className="flex items-center gap-2">
                    {transaction.attachmentUrl && (
                      <button
                        type="button"
                        onClick={() => setShowAttachmentViewer(!showAttachmentViewer)}
                        className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                      >
                        {showAttachmentViewer ? 'Hide Preview' : 'View'}
                      </button>
                    )}

                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*,application/pdf"
                      className="hidden"
                      onChange={handleFileUpload}
                    />

                    <button
                      type="button"
                      onClick={() => fileInputRef.current?.click()}
                      className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] hover:underline flex items-center gap-1 cursor-pointer"
                    >
                      <Upload size={12} />
                      <span>{transaction.attachmentUrl ? 'Replace' : 'Upload'}</span>
                    </button>
                  </div>
                </div>

                {transaction.attachmentUrl ? (
                  showAttachmentViewer ? (
                    <div className="rounded-xl overflow-hidden border border-[#F3DFCD] dark:border-[#383029] mt-2 bg-stone-900 flex flex-col items-center justify-center p-2 gap-2">
                      <img
                        src={transaction.attachmentUrl}
                        alt="Receipt"
                        className="max-h-60 object-contain rounded"
                      />
                      <button
                        type="button"
                        onClick={() => removeReceiptFromTransaction(transaction.id)}
                        className="text-[11px] text-rose-400 hover:underline flex items-center gap-1 cursor-pointer"
                      >
                        <Trash2 size={12} /> Remove Attachment
                      </button>
                    </div>
                  ) : (
                    <div className="text-xs text-[#6B6156] dark:text-[#AC9E92] flex items-center justify-between">
                      <div className="flex items-center gap-1.5 truncate">
                        <CheckCircle2 size={13} className="text-emerald-600 dark:text-emerald-400 shrink-0" />
                        <span className="font-semibold text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {transaction.attachmentName || 'Official Receipt Document'}
                        </span>
                      </div>
                      <button
                        type="button"
                        onClick={() => removeReceiptFromTransaction(transaction.id)}
                        className="text-[11px] text-rose-600 dark:text-rose-400 hover:underline cursor-pointer shrink-0 ml-2"
                      >
                        Remove
                      </button>
                    </div>
                  )
                ) : (
                  <div className="text-xs text-[#6B6156] dark:text-[#AC9E92] flex items-center justify-between">
                    <span>No receipt attached. Upload image/PDF for BIR or audit compliance.</span>
                  </div>
                )}
              </div>

              {/* Transaction Comments & Mentions Thread */}
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5 text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                    <MessageSquare size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <span>Collaborator Comments &amp; Mentions ({transaction.comments?.length || 0})</span>
                  </div>
                </div>

                {/* Comment list */}
                {transaction.comments && transaction.comments.length > 0 ? (
                  <div className="space-y-2 divide-y divide-[#F3DFCD]/40 dark:divide-[#383029]/40">
                    {transaction.comments.map((comm) => (
                      <div key={comm.id} className="pt-2 text-xs flex flex-col gap-1">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-1.5">
                            <span>{comm.authorAvatar || '👤'}</span>
                            <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                              {comm.authorName}
                            </span>
                            <span className="text-[9px] px-1.5 py-0.2 rounded bg-stone-200 dark:bg-stone-800 text-[#5A5148] dark:text-[#C6B8AC] uppercase font-bold">
                              {comm.authorRole}
                            </span>
                          </div>
                          <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                            {new Date(comm.createdAt).toLocaleTimeString('en-PH', {
                              hour: '2-digit',
                              minute: '2-digit',
                            })}
                          </span>
                        </div>

                        <p className="text-[#15120F] dark:text-[#F6EFE8] leading-relaxed pl-5">
                          {comm.text}
                        </p>

                        <div className="pl-5 pt-0.5">
                          <button
                            type="button"
                            onClick={() => {
                              setReplyingToId(comm.id);
                              setCommentText(`@${comm.authorName.split(' ')[0]} `);
                            }}
                            className="text-[10px] text-[#B03C09] dark:text-[#FF9A52] font-semibold hover:underline flex items-center gap-0.5 cursor-pointer"
                          >
                            <CornerDownRight size={10} /> Reply
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                    No comments yet. Mention teammates (e.g. @Sam, @Jake, @Tita Tess) to ask questions or verify expenses.
                  </div>
                )}

                {/* Add Comment Input */}
                <form onSubmit={handleAddComment} className="pt-2 flex flex-col gap-2">
                  {replyingToId && (
                    <div className="flex items-center justify-between text-[11px] bg-amber-500/10 text-amber-800 dark:text-amber-200 px-2 py-1 rounded-lg">
                      <span>Replying to comment...</span>
                      <button
                        type="button"
                        onClick={() => setReplyingToId(null)}
                        className="font-bold hover:underline"
                      >
                        Cancel
                      </button>
                    </div>
                  )}

                  {/* Quick Mention Pills */}
                  <div className="flex items-center gap-1 overflow-x-auto pb-0.5">
                    <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">Mention:</span>
                    {members.map((m) => (
                      <button
                        key={m.id}
                        type="button"
                        onClick={() => setCommentText((prev) => `${prev}@${m.name.split(' ')[0]} `)}
                        className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-white dark:bg-[#1E1915] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] hover:bg-[#FFEEDF] cursor-pointer"
                      >
                        @{m.name.split(' ')[0]}
                      </button>
                    ))}
                  </div>

                  <div className="flex items-center gap-2">
                    <input
                      type="text"
                      value={commentText}
                      onChange={(e) => setCommentText(e.target.value)}
                      placeholder="Add a comment or mention @teammate..."
                      className="flex-1 px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                    <button
                      type="submit"
                      disabled={!commentText.trim()}
                      className="px-3 py-2 rounded-xl bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] font-bold text-xs shadow-xs disabled:opacity-50 cursor-pointer"
                    >
                      <Send size={13} />
                    </button>
                  </div>
                </form>
              </div>

              {/* Change History / Audit Trail */}
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
                <div className="flex items-center gap-1.5 text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] mb-2">
                  <History size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                  <span>Audit Trail &amp; Change History</span>
                </div>

                {transaction.changeHistory && transaction.changeHistory.length > 0 ? (
                  <div className="space-y-2 divide-y divide-[#F3DFCD]/50 dark:divide-[#383029]/50">
                    {transaction.changeHistory.map((rec, idx) => (
                      <div key={idx} className="pt-2 text-[11px] space-y-0.5">
                        <div className="flex justify-between items-center text-[#6B6156] dark:text-[#AC9E92]">
                          <span className="font-semibold capitalize text-[#15120F] dark:text-[#F6EFE8]">
                            Field: {rec.field}
                          </span>
                          <span>{new Date(rec.timestamp).toLocaleString()}</span>
                        </div>
                        <div className="text-[#6B6156] dark:text-[#AC9E92]">
                          Changed from{' '}
                          <span className="font-medium text-rose-600 dark:text-rose-400">
                            {String(rec.fromValue)}
                          </span>{' '}
                          to{' '}
                          <span className="font-medium text-emerald-600 dark:text-emerald-400">
                            {String(rec.toValue)}
                          </span>
                        </div>
                        {rec.note && (
                          <div className="text-[#5A5148] dark:text-[#C6B8AC] italic">
                            "{rec.note}"
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-xs text-[#6B6156] dark:text-[#AC9E92]">
                    Clean ledger entry. No manual post-creation edits recorded.
                  </div>
                )}
              </div>
            </>
          ) : (
            /* EDIT FORM */
            <form onSubmit={handleSave} className="space-y-3">
              <div className="p-2.5 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-800 dark:text-amber-200 text-xs flex items-center gap-2">
                <AlertTriangle size={15} className="shrink-0" />
                <span>
                  Accounting rule: All changes will be permanently logged in the audit trail.
                </span>
              </div>

              {/* Amount */}
              <div>
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Amount (₱)
                </label>
                <input
                  type="number"
                  step="any"
                  required
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              {/* Description / Merchant */}
              <div>
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Description / Merchant
                </label>
                <input
                  type="text"
                  value={merchant}
                  onChange={(e) => setMerchant(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              {/* Entity / Profile Selector */}
              <div>
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Entity / Profile
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {PROFILE_OPTIONS.map((p) => (
                    <button
                      key={p.id}
                      type="button"
                      onClick={() => setProfile(p.id)}
                      className={`p-2 rounded-xl text-xs font-bold capitalize transition-all border text-left cursor-pointer ${
                        profile === p.id
                          ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent'
                          : 'bg-white dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                      }`}
                    >
                      <div>{p.name}</div>
                      <div className="text-[10px] font-normal opacity-80 truncate">{p.description}</div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Status Selector */}
              <div>
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Status Lifecycle
                </label>
                <div className="grid grid-cols-3 gap-1.5">
                  {(['pending', 'confirmed', 'reconciled', 'duplicate', 'corrected', 'excluded'] as TransactionStatus[]).map((st) => (
                    <button
                      key={st}
                      type="button"
                      onClick={() => setStatus(st)}
                      className={`py-1.5 px-2 rounded-xl text-xs font-bold capitalize transition-all border cursor-pointer ${
                        status === st
                          ? 'bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#15120F] border-transparent'
                          : 'bg-white dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                      }`}
                    >
                      {st}
                    </button>
                  ))}
                </div>
              </div>

              {/* Category & Subcategory */}
              {transaction.type !== 'transfer' && (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <div>
                    <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                      Category
                    </label>
                    <select
                      value={category}
                      onChange={(e) => {
                        const newCatName = e.target.value;
                        setCategory(newCatName);
                        const newCatObj = categories.find(
                          (c) => c.name.toLowerCase() === newCatName.toLowerCase()
                        );
                        setSubcategory(newCatObj?.subcategories[0] || '');
                      }}
                      className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                    >
                      {categories
                        .filter((c) =>
                          transaction.type === 'expense'
                            ? c.type === 'expense' || c.type === 'both'
                            : c.type === 'income' || c.type === 'both'
                        )
                        .map((c) => (
                          <option key={c.id} value={c.name}>
                            {c.emoji} {c.name}
                          </option>
                        ))}
                    </select>
                  </div>

                  {subcategoriesList.length > 0 && (
                    <div>
                      <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                        Subcategory
                      </label>
                      <select
                        value={subcategory}
                        onChange={(e) => setSubcategory(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                      >
                        <option value="">Select subcategory (optional)</option>
                        {subcategoriesList.map((sub) => (
                          <option key={sub} value={sub}>
                            {sub}
                          </option>
                        ))}
                      </select>
                    </div>
                  )}
                </div>
              )}

              {/* Person & Tags */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <div>
                  <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Person Involved
                  </label>
                  <input
                    type="text"
                    value={person}
                    onChange={(e) => setPerson(e.target.value)}
                    placeholder="e.g. Kuya Mark, Client A"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Tags (comma separated)
                  </label>
                  <input
                    type="text"
                    value={tagInput}
                    onChange={(e) => setTagInput(e.target.value)}
                    placeholder="#tax-deductible, #sweldo"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
              </div>

              {/* Date & Note */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <div>
                  <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Date
                  </label>
                  <input
                    type="date"
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Notes
                  </label>
                  <input
                    type="text"
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                    placeholder="Details"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
              </div>

              {/* Reason for Change (Audit Requirement) */}
              <div>
                <label className="text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] block mb-1">
                  Audit Reason for Modification (Required for Ledger Traceability)
                </label>
                <input
                  type="text"
                  required
                  value={auditNote}
                  onChange={(e) => setAuditNote(e.target.value)}
                  placeholder="e.g. Corrected official receipt total; reclassified to business profile"
                  className="w-full px-3 py-2 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#B03C09]/40 dark:border-[#FF9A52]/40 text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              {/* Action Buttons */}
              <div className="flex items-center gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsEditing(false)}
                  className="flex-1 py-2.5 rounded-xl border border-[#F3DFCD] dark:border-[#383029] font-bold text-xs text-[#6B6156] dark:text-[#AC9E92] hover:bg-black/5 cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!auditNote.trim()}
                  className="flex-1 py-2.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] font-bold text-xs flex items-center justify-center gap-1.5 shadow-sm hover:opacity-90 disabled:opacity-50 cursor-pointer"
                >
                  <Save size={14} />
                  <span>Save Changes</span>
                </button>
              </div>
            </form>
          )}
        </div>

        {/* Footer with Delete entry */}
        {!isEditing && (
          <div className="px-5 py-3 border-t border-[#F3DFCD] dark:border-[#383029] flex justify-between items-center bg-[#FFEEDF]/30 dark:bg-[#14100D]/30">
            {activePermissions.canDeleteTransactions ? (
              <button
                type="button"
                onClick={handleDelete}
                className="text-xs font-semibold text-rose-600 dark:text-rose-400 flex items-center gap-1 hover:underline cursor-pointer"
              >
                <Trash2 size={13} />
                <span>Delete Entry</span>
              </button>
            ) : (
              <span className="text-[11px] font-semibold text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1">
                <Shield size={12} /> View-Only Session
              </span>
            )}
            <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
              ID: {transaction.id}
            </span>
          </div>
        )}
      </div>
    </div>
  );
};

