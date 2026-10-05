import React, { useState, useMemo } from 'react';
import {
  Users,
  UserPlus,
  ShieldCheck,
  Clock,
  CheckCircle2,
  XCircle,
  MessageSquare,
  Paperclip,
  DollarSign,
  Layers,
  ArrowRightLeft,
  Calendar,
  Filter,
  Download,
  AlertCircle,
  ChevronRight,
  Plus,
  Trash2,
  Edit3,
  ExternalLink,
  Share2,
  Sparkles,
  Info,
  Building,
  Heart,
  Home,
  Briefcase,
  Search,
  Check,
  Lock,
  X,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import {
  CollaborationSpace,
  CollaborationSpaceType,
  CollaborationRole,
  CollaboratorMember,
  ExpenseSplit,
  SplitCategoryType,
  Transaction,
} from '../types';
import { formatPeso } from '../utils/format';
import {
  getRoleBadgeConfig,
  checkMemberAccess,
  calculateSimplifiedDebts,
} from '../utils/collaborationEngine';

export interface CollaborationHubProps {
  isOpen?: boolean;
  onClose?: () => void;
  onOpenSplitBill: (spaceId?: string) => void;
  onOpenTransactionDetail?: (tx: Transaction) => void;
}

export const CollaborationHub: React.FC<CollaborationHubProps> = ({
  isOpen,
  onClose,
  onOpenSplitBill,
  onOpenTransactionDetail,
}) => {
  const {
    spaces,
    activeSpaceId,
    setActiveSpaceId,
    members,
    activeMember,
    switchActiveMember,
    createSpace,
    updateSpace,
    deleteSpace,
    addMember,
    updateMemberRole,
    revokeMemberAccess,
    transactions,
    approveTransaction,
    rejectTransaction,
    expenseSplits,
    recordSplitSettlement,
    deleteExpenseSplit,
    auditLogs,
    exportAuditLogCsv,
    pendingApprovalsCount,
  } = useFinancial();

  // Active section tab within the Collaboration Hub
  const [activeTab, setActiveTab] = useState<'splits' | 'who_owes' | 'approvals' | 'members' | 'audit'>('splits');
  const [splitFilter, setSplitFilter] = useState<SplitCategoryType | 'all'>('all');

  // Modals inside Hub
  const [isCreateSpaceOpen, setIsCreateSpaceOpen] = useState(false);
  const [isInviteMemberOpen, setIsInviteMemberOpen] = useState(false);
  const [isRoleExplainerOpen, setIsRoleExplainerOpen] = useState(false);
  const [rejectionModalTx, setRejectionModalTx] = useState<Transaction | null>(null);
  const [rejectionReason, setRejectionReason] = useState('');
  const [memberToEdit, setMemberToEdit] = useState<CollaboratorMember | null>(null);

  // New Space Form State
  const [newSpaceName, setNewSpaceName] = useState('');
  const [newSpaceType, setNewSpaceType] = useState<CollaborationSpaceType>('couple');
  const [newSpaceEmoji, setNewSpaceEmoji] = useState('💑');
  const [newSpaceDesc, setNewSpaceDesc] = useState('');
  const [newSpaceApprovalLimit, setNewSpaceApprovalLimit] = useState('5000');

  // Invite Member Form State
  const [inviteName, setInviteName] = useState('');
  const [inviteEmail, setInviteEmail] = useState('');
  const [invitePhone, setInvitePhone] = useState('');
  const [inviteRole, setInviteRole] = useState<CollaborationRole>('contributor');
  const [inviteHasExpiry, setInviteHasExpiry] = useState(false);
  const [inviteExpiryDays, setInviteExpiryDays] = useState('14');
  const [inviteNotes, setInviteNotes] = useState('');

  // Settle Share Modal
  const [settlingSplit, setSettlingSplit] = useState<{ splitId: string; memberId: string; memberName: string; amount: number } | null>(null);
  const [settleMethod, setSettleMethod] = useState<'gcash' | 'maya' | 'bank_transfer' | 'cash'>('gcash');

  // Filtered splits according to active space and split filter
  const displayedSplits = useMemo(() => {
    return expenseSplits.filter((split) => {
      if (activeSpaceId !== 'all' && split.spaceId !== activeSpaceId) return false;
      if (splitFilter !== 'all' && split.splitType !== splitFilter) return false;
      return true;
    });
  }, [expenseSplits, activeSpaceId, splitFilter]);

  // Filtered pending approval transactions
  const pendingTransactions = useMemo(() => {
    return transactions.filter((tx) => {
      if (tx.approval?.status !== 'pending_approval') return false;
      if (activeSpaceId !== 'all' && tx.spaceId !== activeSpaceId) return false;
      return true;
    });
  }, [transactions, activeSpaceId]);

  // Simplified Debts ("Who owes whom?") calculation
  const simplifiedDebts = useMemo(() => {
    const spaceSplits = activeSpaceId === 'all'
      ? expenseSplits
      : expenseSplits.filter((s) => s.spaceId === activeSpaceId);
    return calculateSimplifiedDebts(spaceSplits, members);
  }, [expenseSplits, activeSpaceId, members]);

  // Active space object
  const currentSpaceObj = useMemo(() => {
    if (activeSpaceId === 'all') return null;
    return spaces.find((s) => s.id === activeSpaceId) || null;
  }, [spaces, activeSpaceId]);

  // Active member permissions
  const activeMemberAccess = useMemo(() => {
    return checkMemberAccess(activeMember);
  }, [activeMember]);

  const activeRoleBadge = getRoleBadgeConfig(activeMember.role);

  if (isOpen !== undefined && !isOpen) return null;

  const handleCreateSpaceSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newSpaceName.trim()) return;

    createSpace({
      name: newSpaceName.trim(),
      type: newSpaceType,
      emoji: newSpaceEmoji,
      description: newSpaceDesc.trim() || '',
      accountIds: [],
      members: [
        {
          ...activeMember,
          role: 'owner',
        },
      ],
      requireApprovalsAbove: parseFloat(newSpaceApprovalLimit) || undefined,
    });

    setNewSpaceName('');
    setNewSpaceDesc('');
    setIsCreateSpaceOpen(false);
  };

  const handleInviteMemberSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!inviteName.trim()) return;

    const expiryTimestamp = inviteHasExpiry
      ? Date.now() + parseInt(inviteExpiryDays, 10) * 86400000
      : null;

    addMember({
      name: inviteName.trim(),
      email: inviteEmail.trim() || undefined,
      phoneOrGcash: invitePhone.trim() || undefined,
      role: inviteRole,
      avatar: inviteRole === 'view_only' ? '💼' : inviteRole === 'contributor' ? '🙋🏻' : '👨🏻‍💻',
      color: inviteRole === 'owner' ? '#B03C09' : inviteRole === 'editor' ? '#2563EB' : inviteRole === 'contributor' ? '#059669' : '#7C3AED',
      expiresAt: expiryTimestamp,
      notes: inviteNotes.trim() || undefined,
    });

    setInviteName('');
    setInviteEmail('');
    setInvitePhone('');
    setInviteNotes('');
    setInviteHasExpiry(false);
    setIsInviteMemberOpen(false);
  };

  const handleConfirmRejection = () => {
    if (!rejectionModalTx || !rejectionReason.trim()) return;
    rejectTransaction(rejectionModalTx.id, rejectionReason.trim());
    setRejectionModalTx(null);
    setRejectionReason('');
  };

  const handleConfirmSettlement = () => {
    if (!settlingSplit) return;
    recordSplitSettlement(
      settlingSplit.splitId,
      settlingSplit.memberId,
      settleMethod
    );
    setSettlingSplit(null);
  };

  const hubContent = (
    <div className="flex flex-col gap-4">
      {/* 1. Header Banner & Active Actor Bar */}
      <div className="p-4 rounded-3xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs flex flex-col gap-3">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className="w-10 h-10 rounded-2xl bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0 shadow-xs">
              <Users size={20} />
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-1.5 flex-wrap">
                <h2 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] truncate">
                  Shared Finances
                </h2>
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/20">
                  Phase 5
                </span>
              </div>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] truncate">
                Couples, households, barkada splits, &amp; business partners
              </p>
            </div>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            <button
              type="button"
              id="role-guide-btn"
              onClick={() => setIsRoleExplainerOpen(true)}
              className="px-2.5 py-1.5 rounded-xl text-xs font-semibold bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] hover:opacity-90 flex items-center gap-1 cursor-pointer"
            >
              <ShieldCheck size={14} />
              <span className="hidden sm:inline">Role Guide</span>
            </button>
            {onClose && (
              <button
                type="button"
                onClick={onClose}
                className="p-1.5 rounded-xl text-[#7A6E63] dark:text-[#A89A8D] hover:bg-[#FFEEDF] dark:hover:bg-[#2A221C] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
                title="Close Collaboration Hub"
              >
                <X size={18} />
              </button>
            )}
          </div>
        </div>

        {/* Actor Switcher Row (Simulates multi-user collaboration in offline-first mode) */}
        <div className="p-2.5 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F0D5C0]/60 dark:border-[#383029] flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-xs">
          <div className="flex items-center gap-2 min-w-0">
            <span className="text-base">{activeMember.avatar || '👤'}</span>
            <div className="min-w-0">
              <div className="flex items-center gap-1.5">
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                  {activeMember.name}
                </span>
                <span
                  className={`text-[10px] font-bold px-2 py-0.5 rounded-full border uppercase tracking-wider ${activeRoleBadge.bg} ${activeRoleBadge.text} ${activeRoleBadge.border}`}
                >
                  {activeRoleBadge.label}
                </span>
              </div>
              <span className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] truncate block">
                {activeMember.notes || 'Current simulated session'}
              </span>
            </div>
          </div>

          {/* Quick Member Dropdown Switcher */}
          <div className="flex items-center gap-1.5 shrink-0 self-end sm:self-center">
            <span className="text-[10px] font-semibold text-[#5A5148] dark:text-[#C6B8AC]">
              Switch Actor:
            </span>
            <select
              value={activeMember.id}
              onChange={(e) => switchActiveMember(e.target.value)}
              className="px-2.5 py-1 rounded-xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
            >
              {members.map((m) => (
                <option key={m.id} value={m.id}>
                  {m.avatar} {m.name} ({m.role.toUpperCase()})
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* 2. Space Selector Tabs (Couple, Household, Friends, Business, Tax Adviser) */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
        <button
          type="button"
          onClick={() => setActiveSpaceId('all')}
          className={`px-3.5 py-2 rounded-2xl text-xs font-bold whitespace-nowrap transition-all border cursor-pointer ${
            activeSpaceId === 'all'
              ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent shadow-xs'
              : 'bg-white dark:bg-[#1E1915] text-[#5A5148] dark:text-[#C6B8AC] border-[#F0D5C0] dark:border-[#383029]'
          }`}
        >
          🌐 All Spaces
        </button>

        {spaces.map((sp) => {
          const isSelected = activeSpaceId === sp.id;
          return (
            <button
              key={sp.id}
              type="button"
              onClick={() => setActiveSpaceId(sp.id)}
              className={`px-3.5 py-2 rounded-2xl text-xs font-bold whitespace-nowrap transition-all border flex items-center gap-1.5 cursor-pointer ${
                isSelected
                  ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent shadow-xs'
                  : 'bg-white dark:bg-[#1E1915] text-[#5A5148] dark:text-[#C6B8AC] border-[#F0D5C0] dark:border-[#383029]'
              }`}
            >
              <span>{sp.emoji}</span>
              <span>{sp.name}</span>
            </button>
          );
        })}

        {activeMemberAccess.canManageSpaces && (
          <button
            type="button"
            onClick={() => setIsCreateSpaceOpen(true)}
            className="px-3 py-2 rounded-2xl text-xs font-bold bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] border border-dashed border-[#B03C09]/40 dark:border-[#FF9A52]/40 whitespace-nowrap flex items-center gap-1 cursor-pointer hover:opacity-90"
          >
            <Plus size={14} />
            <span>New Space</span>
          </button>
        )}
      </div>

      {/* 3. Space Summary Meta (if single space is active) */}
      {currentSpaceObj && (
        <div className="p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] flex items-center justify-between gap-3 text-xs">
          <div className="min-w-0">
            <div className="flex items-center gap-2">
              <span className="text-xl">{currentSpaceObj.emoji}</span>
              <div>
                <span className="font-extrabold text-sm text-[#15120F] dark:text-[#F6EFE8]">
                  {currentSpaceObj.name}
                </span>
                <span className="ml-2 text-[10px] font-bold px-2 py-0.2 rounded-md bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] uppercase">
                  {currentSpaceObj.type}
                </span>
              </div>
            </div>
            {currentSpaceObj.description && (
              <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] mt-1">
                {currentSpaceObj.description}
              </p>
            )}
          </div>

          <div className="text-right shrink-0">
            <span className="text-[10px] text-[#5A5148] dark:text-[#C6B8AC] block">
              {currentSpaceObj.members.length} Members
            </span>
            {currentSpaceObj.requireApprovalsAbove && (
              <span className="text-[10px] font-semibold text-amber-600 dark:text-amber-400">
                Approvals &gt; ₱{currentSpaceObj.requireApprovalsAbove.toLocaleString()}
              </span>
            )}
          </div>
        </div>
      )}

      {/* 4. Sub-Navigation Tabs: Splits, "Who owes whom?", Approvals Queue, Members, Audit Log */}
      <div className="grid grid-cols-5 gap-1 p-1 bg-[#FFEEDF]/60 dark:bg-[#14100D] rounded-2xl border border-[#F0D5C0] dark:border-[#383029] text-xs">
        <button
          type="button"
          onClick={() => setActiveTab('splits')}
          className={`py-2 px-1 rounded-xl font-bold transition-all text-center flex flex-col items-center gap-0.5 cursor-pointer ${
            activeTab === 'splits'
              ? 'bg-white dark:bg-[#1E1915] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
              : 'text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <ArrowRightLeft size={14} />
          <span className="text-[10px] truncate">Splits</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('who_owes')}
          className={`py-2 px-1 rounded-xl font-bold transition-all text-center flex flex-col items-center gap-0.5 cursor-pointer ${
            activeTab === 'who_owes'
              ? 'bg-white dark:bg-[#1E1915] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
              : 'text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <DollarSign size={14} />
          <span className="text-[10px] truncate">Who Owes</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('approvals')}
          className={`py-2 px-1 rounded-xl font-bold transition-all text-center flex flex-col items-center gap-0.5 relative cursor-pointer ${
            activeTab === 'approvals'
              ? 'bg-white dark:bg-[#1E1915] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
              : 'text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <CheckCircle2 size={14} />
          <span className="text-[10px] truncate">Approvals</span>
          {pendingApprovalsCount > 0 && (
            <span className="absolute top-1 right-1 w-4 h-4 rounded-full bg-amber-500 text-amber-950 font-extrabold text-[9px] flex items-center justify-center">
              {pendingApprovalsCount}
            </span>
          )}
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('members')}
          className={`py-2 px-1 rounded-xl font-bold transition-all text-center flex flex-col items-center gap-0.5 cursor-pointer ${
            activeTab === 'members'
              ? 'bg-white dark:bg-[#1E1915] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
              : 'text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <Users size={14} />
          <span className="text-[10px] truncate">Members</span>
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('audit')}
          className={`py-2 px-1 rounded-xl font-bold transition-all text-center flex flex-col items-center gap-0.5 cursor-pointer ${
            activeTab === 'audit'
              ? 'bg-white dark:bg-[#1E1915] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
              : 'text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
          }`}
        >
          <Clock size={14} />
          <span className="text-[10px] truncate">Audit Log</span>
        </button>
      </div>

      {/* 5. TAB 1: SPLITS (Shared Bills & Expenses) */}
      {activeTab === 'splits' && (
        <div className="flex flex-col gap-3">
          {/* Action Bar & Split Type Filters */}
          <div className="flex items-center justify-between gap-2 flex-wrap">
            <div className="flex items-center gap-1 overflow-x-auto pb-0.5">
              {(['all', 'couple', 'household', 'friends', 'business'] as const).map((filterKey) => (
                <button
                  key={filterKey}
                  type="button"
                  onClick={() => setSplitFilter(filterKey)}
                  className={`px-2.5 py-1 rounded-xl text-xs font-semibold capitalize transition-all border cursor-pointer ${
                    splitFilter === filterKey
                      ? 'bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#15120F] border-transparent'
                      : 'bg-white dark:bg-[#1E1915] text-[#5A5148] dark:text-[#C6B8AC] border-[#F0D5C0] dark:border-[#383029]'
                  }`}
                >
                  {filterKey === 'all' ? 'All Splits' : filterKey}
                </button>
              ))}
            </div>

            {activeMemberAccess.canCreateSplits && (
              <button
                type="button"
                id="create-split-btn"
                onClick={() => onOpenSplitBill(activeSpaceId !== 'all' ? activeSpaceId : undefined)}
                className="px-3 py-1.5 rounded-xl bg-[#B03C09] hover:bg-[#963307] text-white dark:bg-[#FF9A52] dark:hover:bg-[#ff8a38] dark:text-[#14100D] font-bold text-xs flex items-center gap-1 shadow-xs cursor-pointer"
              >
                <Plus size={14} />
                <span>Split Bill</span>
              </button>
            )}
          </div>

          {/* Splits List */}
          {displayedSplits.length === 0 ? (
            <div className="p-8 rounded-3xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] text-center flex flex-col items-center justify-center gap-2">
              <span className="text-3xl">🧾</span>
              <h3 className="font-bold text-sm text-[#15120F] dark:text-[#F6EFE8]">
                No Expense Splits Found
              </h3>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] max-w-xs">
                Split restaurant dinners, electricity bills, rent, or business software subscriptions across partners and roommates.
              </p>
              {activeMemberAccess.canCreateSplits && (
                <button
                  type="button"
                  onClick={() => onOpenSplitBill(activeSpaceId !== 'all' ? activeSpaceId : undefined)}
                  className="mt-2 px-4 py-2 rounded-2xl bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] font-bold text-xs cursor-pointer"
                >
                  Create First Split
                </button>
              )}
            </div>
          ) : (
            displayedSplits.map((split) => {
              const totalPaid = split.participants
                .filter((p) => p.hasPaid)
                .reduce((acc, p) => acc + p.shareAmount, 0);
              const progressPct = Math.round((totalPaid / split.totalAmount) * 100);

              return (
                <div
                  key={split.id}
                  className="p-4 rounded-3xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs flex flex-col gap-3"
                >
                  {/* Split Header */}
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="font-extrabold text-sm text-[#15120F] dark:text-[#F6EFE8]">
                          {split.title}
                        </span>
                        <span className="text-[10px] font-bold px-2 py-0.2 rounded-full bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52] uppercase">
                          {split.splitType}
                        </span>
                        {split.isFullySettled ? (
                          <span className="text-[10px] font-bold px-2 py-0.2 rounded-full bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border border-emerald-500/20">
                            Fully Settled
                          </span>
                        ) : (
                          <span className="text-[10px] font-bold px-2 py-0.2 rounded-full bg-amber-500/15 text-amber-700 dark:text-amber-300 border border-amber-500/20">
                            Active ({progressPct}%)
                          </span>
                        )}
                      </div>

                      <div className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mt-0.5 flex items-center gap-2">
                        <span>Payer: <strong className="text-[#15120F] dark:text-[#F6EFE8]">{split.payerName}</strong></span>
                        <span>-</span>
                        <span className="capitalize">{split.splitMethod} split</span>
                        {split.dueDate && (
                          <>
                            <span>-</span>
                            <span>Due {split.dueDate}</span>
                          </>
                        )}
                      </div>
                    </div>

                    <div className="text-right shrink-0">
                      <div className="font-extrabold text-base text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                        {formatPeso(split.totalAmount)}
                      </div>
                      {split.receiptUrl && (
                        <span className="text-[10px] font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-end gap-0.5 mt-0.5">
                          <Paperclip size={10} /> Receipt
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Settlement Progress Bar */}
                  <div className="w-full bg-[#FFEEDF] dark:bg-[#2A221C] h-2 rounded-full overflow-hidden">
                    <div
                      className={`h-full transition-all duration-300 ${
                        split.isFullySettled ? 'bg-emerald-500' : 'bg-[#B03C09] dark:bg-[#FF9A52]'
                      }`}
                      style={{ width: `${progressPct}%` }}
                    />
                  </div>

                  {/* Participants Breakdown List */}
                  <div className="space-y-1.5 pt-1">
                    {split.participants.map((participant) => (
                      <div
                        key={participant.memberId}
                        className="p-2.5 rounded-2xl bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border border-[#F0D5C0]/60 dark:border-[#383029]/60 flex items-center justify-between gap-2 text-xs"
                      >
                        <div className="flex items-center gap-2 min-w-0">
                          <div
                            className={`w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold ${
                              participant.hasPaid
                                ? 'bg-emerald-500 text-white'
                                : 'bg-amber-400 text-amber-950'
                            }`}
                          >
                            {participant.hasPaid ? <Check size={11} /> : '₱'}
                          </div>

                          <div className="min-w-0">
                            <div className="flex items-center gap-1.5">
                              <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                                {participant.name}
                              </span>
                              {participant.sharePercentage && (
                                <span className="text-[10px] text-[#5A5148] dark:text-[#C6B8AC]">
                                  ({participant.sharePercentage}%)
                                </span>
                              )}
                            </div>
                            {participant.notes && (
                              <span className="text-[10px] text-[#5A5148] dark:text-[#C6B8AC] truncate block">
                                {participant.notes}
                              </span>
                            )}
                          </div>
                        </div>

                        <div className="flex items-center gap-2 shrink-0">
                          <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                            {formatPeso(participant.shareAmount)}
                          </span>

                          {participant.hasPaid ? (
                            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/15 text-emerald-700 dark:text-emerald-300">
                              Paid {participant.settledMethod ? `(${participant.settledMethod.toUpperCase()})` : ''}
                            </span>
                          ) : (
                            <button
                              type="button"
                              onClick={() =>
                                setSettlingSplit({
                                  splitId: split.id,
                                  memberId: participant.memberId,
                                  memberName: participant.name,
                                  amount: participant.shareAmount,
                                })
                              }
                              className="px-2.5 py-1 rounded-xl text-[11px] font-bold bg-emerald-600 hover:bg-emerald-700 text-white cursor-pointer shadow-xs"
                            >
                              Settle
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>

                  {/* Split Footer Notes & Delete */}
                  <div className="flex items-center justify-between text-[11px] text-[#5A5148] dark:text-[#C6B8AC] pt-1 border-t border-[#F0D5C0]/40 dark:border-[#383029]/40">
                    <span className="truncate">
                      {split.notes || 'Equal share payment ledger'}
                    </span>
                    {activeMemberAccess.canManageSpaces && (
                      <button
                        type="button"
                        onClick={() => {
                          if (window.confirm('Delete this expense split?')) {
                            deleteExpenseSplit(split.id);
                          }
                        }}
                        className="text-rose-600 dark:text-rose-400 hover:underline cursor-pointer flex items-center gap-0.5 ml-2"
                      >
                        <Trash2 size={11} /> Delete
                      </button>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* 6. TAB 2: WHO OWES WHOM (Simplified Peer-to-Peer Net Debt Matrix) */}
      {activeTab === 'who_owes' && (
        <div className="flex flex-col gap-3">
          <div className="p-4 rounded-3xl bg-gradient-to-br from-[#FFEEDF] to-white dark:from-[#2A221C] dark:to-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs">
            <div className="flex items-center gap-2 mb-1">
              <DollarSign className="text-[#B03C09] dark:text-[#FF9A52]" size={18} />
              <h3 className="font-extrabold text-sm text-[#15120F] dark:text-[#F6EFE8]">
                Optimal Settlement Path
              </h3>
            </div>
            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
              Salapify's net debt algorithm simplifies multiple cross-debts into the fewest direct transfers.
            </p>
          </div>

          {simplifiedDebts.length === 0 ? (
            <div className="p-8 rounded-3xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] text-center flex flex-col items-center justify-center gap-2">
              <span className="text-3xl">🎉</span>
              <h3 className="font-bold text-sm text-[#15120F] dark:text-[#F6EFE8]">
                All Shared Balances Settled
              </h3>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                No pending debts across members in this space. All accounts are square!
              </p>
            </div>
          ) : (
            simplifiedDebts.map((item, idx) => (
              <div
                key={idx}
                className="p-4 rounded-3xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs flex items-center justify-between gap-3"
              >
                <div className="flex items-center gap-3 min-w-0">
                  <div className="w-10 h-10 rounded-2xl bg-amber-500/15 text-amber-800 dark:text-amber-200 border border-amber-500/20 flex items-center justify-center font-bold text-sm shrink-0">
                    💸
                  </div>

                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <span className="font-extrabold text-xs text-[#15120F] dark:text-[#F6EFE8]">
                        {item.fromName}
                      </span>
                      <span className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC]">
                        owes
                      </span>
                      <span className="font-extrabold text-xs text-[#B03C09] dark:text-[#FF9A52]">
                        {item.toName}
                      </span>
                    </div>
                    <span className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] block">
                      Direct settlement to clear shared balance
                    </span>
                  </div>
                </div>

                <div className="text-right shrink-0">
                  <div className="text-sm font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                    {formatPeso(item.amount)}
                  </div>
                  <span className="text-[10px] font-bold text-emerald-600 dark:text-emerald-400 block mt-0.5">
                    GCash / Maya QR Ph
                  </span>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {/* 7. TAB 3: APPROVALS QUEUE */}
      {activeTab === 'approvals' && (
        <div className="flex flex-col gap-3">
          <div className="p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] flex items-center justify-between text-xs">
            <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
              Pending Approval Queue ({pendingTransactions.length})
            </span>
            <span className="text-[#5A5148] dark:text-[#C6B8AC]">
              {activeMemberAccess.canApproveTransactions
                ? 'You have permission to approve/reject'
                : 'View-only queue'}
            </span>
          </div>

          {pendingTransactions.length === 0 ? (
            <div className="p-8 rounded-3xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] text-center flex flex-col items-center justify-center gap-2">
              <span className="text-3xl">✅</span>
              <h3 className="font-bold text-sm text-[#15120F] dark:text-[#F6EFE8]">
                Approvals Queue Clean
              </h3>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
                All collaborator transactions have been reviewed and verified.
              </p>
            </div>
          ) : (
            pendingTransactions.map((tx) => (
              <div
                key={tx.id}
                className="p-4 rounded-3xl bg-white dark:bg-[#1E1915] border border-amber-500/40 dark:border-amber-500/30 shadow-xs flex flex-col gap-3"
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <span className="font-extrabold text-sm text-[#15120F] dark:text-[#F6EFE8]">
                        {tx.merchant || tx.category}
                      </span>
                      <span className="text-[10px] font-bold px-2 py-0.2 rounded-full bg-amber-500/20 text-amber-800 dark:text-amber-200">
                        Needs Approval
                      </span>
                    </div>

                    <div className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mt-0.5">
                      Logged by <strong>{tx.collaboratorName || tx.approval?.requestedBy || 'Contributor'}</strong> on {tx.date}
                    </div>
                  </div>

                  <div className="text-right shrink-0">
                    <div className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8] tabular-nums">
                      {formatPeso(tx.amount)}
                    </div>
                    {tx.attachmentUrl && (
                      <span className="text-[10px] font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-end gap-0.5 mt-0.5">
                        <Paperclip size={10} /> Has Receipt
                      </span>
                    )}
                  </div>
                </div>

                {tx.note && (
                  <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 p-2.5 rounded-xl">
                    "{tx.note}"
                  </p>
                )}

                {/* Actions: View Details, Approve, Reject */}
                <div className="flex items-center justify-between gap-2 pt-1 border-t border-[#F0D5C0]/40 dark:border-[#383029]/40">
                  <button
                    type="button"
                    onClick={() => onOpenTransactionDetail?.(tx)}
                    className="text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer flex items-center gap-1"
                  >
                    <span>View &amp; Comments</span>
                    <ChevronRight size={13} />
                  </button>

                  {activeMemberAccess.canApproveTransactions && (
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={() => setRejectionModalTx(tx)}
                        className="px-3 py-1.5 rounded-xl border border-rose-500/40 text-rose-600 dark:text-rose-400 font-bold text-xs hover:bg-rose-500/10 cursor-pointer"
                      >
                        Reject
                      </button>
                      <button
                        type="button"
                        onClick={() => approveTransaction(tx.id, 'Verified and approved')}
                        className="px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-xs cursor-pointer flex items-center gap-1"
                      >
                        <Check size={13} />
                        <span>Approve</span>
                      </button>
                    </div>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {/* 8. TAB 4: MEMBERS & EXPIRING ACCESS */}
      {activeTab === 'members' && (
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between gap-2">
            <span className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
              Space Members &amp; Access Expiry ({members.length})
            </span>

            {activeMemberAccess.canManageSpaces && (
              <button
                type="button"
                id="invite-member-btn"
                onClick={() => setIsInviteMemberOpen(true)}
                className="px-3 py-1.5 rounded-xl bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] font-bold text-xs flex items-center gap-1 cursor-pointer shadow-xs"
              >
                <UserPlus size={13} />
                <span>Invite Member</span>
              </button>
            )}
          </div>

          <div className="space-y-2.5">
            {members.map((member) => {
              const roleConfig = getRoleBadgeConfig(member.role);
              const isExpired = member.expiresAt ? Date.now() > member.expiresAt : false;
              const daysLeft = member.expiresAt
                ? Math.max(0, Math.ceil((member.expiresAt - Date.now()) / 86400000))
                : null;

              return (
                <div
                  key={member.id}
                  className="p-4 rounded-3xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] shadow-xs flex flex-col gap-2.5"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex items-center gap-2.5 min-w-0">
                      <div
                        className="w-10 h-10 rounded-2xl flex items-center justify-center text-lg shrink-0 shadow-xs"
                        style={{ backgroundColor: `${member.color || '#B03C09'}20` }}
                      >
                        {member.avatar || '👤'}
                      </div>

                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className="font-extrabold text-sm text-[#15120F] dark:text-[#F6EFE8] truncate">
                            {member.name}
                          </span>
                          {member.isCurrentActor && (
                            <span className="text-[9px] font-bold px-1.5 py-0.2 rounded-md bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52]">
                              YOU
                            </span>
                          )}
                        </div>

                        <div className="text-xs text-[#5A5148] dark:text-[#C6B8AC] truncate">
                          {member.email || member.phoneOrGcash || 'No contact specified'}
                        </div>
                      </div>
                    </div>

                    <div className="text-right shrink-0">
                      <span
                        className={`text-[10px] font-bold px-2.5 py-1 rounded-full border uppercase tracking-wider ${roleConfig.bg} ${roleConfig.text} ${roleConfig.border}`}
                      >
                        {roleConfig.label}
                      </span>
                    </div>
                  </div>

                  {/* Expiration or Status Row */}
                  <div className="flex items-center justify-between text-xs pt-1 border-t border-[#F0D5C0]/40 dark:border-[#383029]/40">
                    <div className="flex items-center gap-1.5 text-[11px]">
                      {member.expiresAt ? (
                        isExpired ? (
                          <span className="font-bold text-rose-600 dark:text-rose-400 flex items-center gap-1">
                            <AlertCircle size={12} /> Access Expired
                          </span>
                        ) : (
                          <span className="font-bold text-amber-600 dark:text-amber-400 flex items-center gap-1">
                            <Clock size={12} /> Expires in {daysLeft} day{daysLeft === 1 ? '' : 's'}
                          </span>
                        )
                      ) : (
                        <span className="text-[#5A5148] dark:text-[#C6B8AC]">
                          Permanent Access
                        </span>
                      )}
                    </div>

                    {/* Manage Role button (Owner only) */}
                    {activeMemberAccess.canManageSpaces && member.id !== activeMember.id && (
                      <div className="flex items-center gap-2">
                        <button
                          type="button"
                          onClick={() => setMemberToEdit(member)}
                          className="text-[11px] font-semibold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                        >
                          Change Role
                        </button>
                        <button
                          type="button"
                          onClick={() => {
                            if (window.confirm(`Revoke access for ${member.name}?`)) {
                              revokeMemberAccess(member.id);
                            }
                          }}
                          className="text-[11px] font-semibold text-rose-600 dark:text-rose-400 hover:underline cursor-pointer"
                        >
                          Revoke
                        </button>
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* 9. TAB 5: AUDIT LOG TRAIL */}
      {activeTab === 'audit' && (
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between gap-2">
            <span className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
              Immutable Collaboration Trail ({auditLogs.length} Events)
            </span>

            <button
              type="button"
              id="export-audit-csv-btn"
              onClick={exportAuditLogCsv}
              className="px-3 py-1.5 rounded-xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5 shadow-xs cursor-pointer hover:bg-[#FFEEDF]/30"
            >
              <Download size={13} />
              <span>Export CSV</span>
            </button>
          </div>

          <div className="space-y-2">
            {auditLogs.map((log) => (
              <div
                key={log.id}
                className="p-3.5 rounded-2xl bg-white dark:bg-[#1E1915] border border-[#F0D5C0] dark:border-[#383029] text-xs flex flex-col gap-1"
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5 min-w-0">
                    <span className="font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                      {log.actorName}
                    </span>
                    <span className="text-[10px] px-1.5 py-0.2 rounded bg-stone-100 dark:bg-stone-800 text-[#5A5148] dark:text-[#C6B8AC] uppercase font-bold">
                      {log.actorRole}
                    </span>
                  </div>

                  <span className="text-[10px] text-[#5A5148] dark:text-[#C6B8AC] shrink-0">
                    {new Date(log.timestamp).toLocaleString('en-PH', {
                      month: 'short',
                      day: 'numeric',
                      hour: '2-digit',
                      minute: '2-digit',
                    })}
                  </span>
                </div>

                <div className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  {log.title}
                </div>

                {log.description && (
                  <p className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
                    {log.description}
                  </p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* MODAL: Settle Split Participant */}
      {settlingSplit && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#1E1915] rounded-3xl p-5 shadow-2xl border border-[#F0D5C0] dark:border-[#383029] space-y-4">
            <h3 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
              Record Settlement
            </h3>

            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
              Mark <strong>{settlingSplit.memberName}</strong>'s share of{' '}
              <strong className="text-emerald-600 dark:text-emerald-400">
                {formatPeso(settlingSplit.amount)}
              </strong>{' '}
              as settled.
            </p>

            <div>
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                Payment Channel
              </label>
              <select
                value={settleMethod}
                onChange={(e) => setSettleMethod(e.target.value as any)}
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
              >
                <option value="gcash">GCash (QR Ph / Express Send)</option>
                <option value="maya">Maya (Wallet Transfer)</option>
                <option value="bank_transfer">Bank Transfer (InstaPay / PESONet)</option>
                <option value="cash">Cash in Hand (Kaliwaan)</option>
              </select>
            </div>

            <div className="flex items-center gap-2 pt-2">
              <button
                type="button"
                onClick={() => setSettlingSplit(null)}
                className="flex-1 py-2 rounded-xl border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmSettlement}
                className="flex-1 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-xs cursor-pointer"
              >
                Confirm Paid
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: Reject Transaction with Reason */}
      {rejectionModalTx && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#1E1915] rounded-3xl p-5 shadow-2xl border border-rose-500/40 space-y-4">
            <h3 className="text-base font-extrabold text-rose-600 dark:text-rose-400">
              Reject Transaction
            </h3>

            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC]">
              Provide a clear reason for rejecting {rejectionModalTx.merchant || rejectionModalTx.category} ({formatPeso(rejectionModalTx.amount)}).
            </p>

            <div>
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                Rejection Reason (Required)
              </label>
              <input
                type="text"
                required
                value={rejectionReason}
                onChange={(e) => setRejectionReason(e.target.value)}
                placeholder="e.g. Official receipt missing or personal expense"
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-rose-500/30 text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
              />
            </div>

            <div className="flex items-center gap-2 pt-2">
              <button
                type="button"
                onClick={() => setRejectionModalTx(null)}
                className="flex-1 py-2 rounded-xl border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={!rejectionReason.trim()}
                onClick={handleConfirmRejection}
                className="flex-1 py-2 rounded-xl bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold disabled:opacity-50 cursor-pointer shadow-xs"
              >
                Confirm Rejection
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: Role Explainer & Permissions Guide */}
      {isRoleExplainerOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-[#1E1915] rounded-3xl p-5 shadow-2xl border border-[#F0D5C0] dark:border-[#383029] max-h-[85vh] overflow-y-auto space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <ShieldCheck className="text-[#B03C09] dark:text-[#FF9A52]" size={20} />
                <h3 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                  Roles &amp; Permissions Guide
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setIsRoleExplainerOpen(false)}
                className="p-1 text-[#5A5148] dark:text-[#C6B8AC] hover:text-[#15120F] dark:hover:text-[#F6EFE8]"
              >
                ✕
              </button>
            </div>

            <div className="space-y-3 text-xs">
              {/* Owner */}
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029]">
                <div className="flex items-center justify-between font-extrabold text-[#B03C09] dark:text-[#FF9A52] mb-1">
                  <span>👑 Owner</span>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-[#B03C09]/10">Full Control</span>
                </div>
                <p className="text-[#5A5148] dark:text-[#C6B8AC]">
                  Complete access. Can create/delete spaces, invite or remove members, assign roles, approve high-value transactions, and manage all accounts.
                </p>
              </div>

              {/* Editor */}
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029]">
                <div className="flex items-center justify-between font-extrabold text-blue-600 dark:text-blue-400 mb-1">
                  <span>✏️ Editor</span>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-blue-500/10">Co-Manager</span>
                </div>
                <p className="text-[#5A5148] dark:text-[#C6B8AC]">
                  Ideal for partners and co-managers. Can log transactions, create splits, settle balances, review approvals, and upload receipts.
                </p>
              </div>

              {/* Contributor */}
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029]">
                <div className="flex items-center justify-between font-extrabold text-emerald-600 dark:text-emerald-400 mb-1">
                  <span>🙋🏻 Contributor</span>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/10">Roommate / Barkada</span>
                </div>
                <p className="text-[#5A5148] dark:text-[#C6B8AC]">
                  Can log shared expenses, attach receipts, add comments, and request approvals. Cannot edit other members' private records.
                </p>
              </div>

              {/* View-Only */}
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029]">
                <div className="flex items-center justify-between font-extrabold text-purple-600 dark:text-purple-400 mb-1">
                  <span>💼 View-Only</span>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-purple-500/10">CPA / Tax Adviser</span>
                </div>
                <p className="text-[#5A5148] dark:text-[#C6B8AC]">
                  Read-only audit access. Can view transactions, download receipts, review reports, and leave advisory comments with expiring validity.
                </p>
              </div>
            </div>

            <button
              type="button"
              onClick={() => setIsRoleExplainerOpen(false)}
              className="w-full py-2.5 rounded-2xl bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] font-bold text-xs cursor-pointer"
            >
              Got it
            </button>
          </div>
        </div>
      )}

      {/* MODAL: Create New Collaboration Space */}
      {isCreateSpaceOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-[#1E1915] rounded-3xl p-5 shadow-2xl border border-[#F0D5C0] dark:border-[#383029] space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                Create Collaboration Space
              </h3>
              <button
                type="button"
                onClick={() => setIsCreateSpaceOpen(false)}
                className="p-1 text-[#5A5148] dark:text-[#C6B8AC]"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateSpaceSubmit} className="space-y-3 text-xs">
              <div>
                <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Space Name
                </label>
                <input
                  type="text"
                  required
                  value={newSpaceName}
                  onChange={(e) => setNewSpaceName(e.target.value)}
                  placeholder="e.g. Sam & Carla, BGC Condo 14B, Siargao Trip"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Space Type
                  </label>
                  <select
                    value={newSpaceType}
                    onChange={(e) => {
                      const t = e.target.value as CollaborationSpaceType;
                      setNewSpaceType(t);
                      if (t === 'couple') setNewSpaceEmoji('💑');
                      else if (t === 'household') setNewSpaceEmoji('🏠');
                      else if (t === 'friends') setNewSpaceEmoji('🏖️');
                      else if (t === 'business') setNewSpaceEmoji('💼');
                      else setNewSpaceEmoji('📊');
                    }}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  >
                    <option value="couple">Couple / Partner</option>
                    <option value="household">Household / Roommates</option>
                    <option value="friends">Friends / Trip</option>
                    <option value="business">Business Partners</option>
                    <option value="adviser">CPA / Adviser Audit</option>
                  </select>
                </div>

                <div>
                  <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Emoji Icon
                  </label>
                  <input
                    type="text"
                    value={newSpaceEmoji}
                    onChange={(e) => setNewSpaceEmoji(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-center text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Description (Optional)
                </label>
                <input
                  type="text"
                  value={newSpaceDesc}
                  onChange={(e) => setNewSpaceDesc(e.target.value)}
                  placeholder="Purpose of this shared space"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              <div>
                <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Require Approvals for Expenses Above (₱)
                </label>
                <input
                  type="number"
                  value={newSpaceApprovalLimit}
                  onChange={(e) => setNewSpaceApprovalLimit(e.target.value)}
                  placeholder="e.g. 5000"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              <div className="flex items-center gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsCreateSpaceOpen(false)}
                  className="flex-1 py-2.5 rounded-2xl border border-[#F0D5C0] dark:border-[#383029] font-bold text-xs text-[#5A5148] dark:text-[#C6B8AC]"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2.5 rounded-2xl bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] font-bold text-xs shadow-xs cursor-pointer"
                >
                  Create Space
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Invite Member with Role & Expiring Access */}
      {isInviteMemberOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-md bg-white dark:bg-[#1E1915] rounded-3xl p-5 shadow-2xl border border-[#F0D5C0] dark:border-[#383029] space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                Invite Collaborator
              </h3>
              <button
                type="button"
                onClick={() => setIsInviteMemberOpen(false)}
                className="p-1 text-[#5A5148] dark:text-[#C6B8AC]"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleInviteMemberSubmit} className="space-y-3 text-xs">
              <div>
                <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Full Name
                </label>
                <input
                  type="text"
                  required
                  value={inviteName}
                  onChange={(e) => setInviteName(e.target.value)}
                  placeholder="e.g. Sam Rivera, Tita Tess CPA"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    Email (Optional)
                  </label>
                  <input
                    type="email"
                    value={inviteEmail}
                    onChange={(e) => setInviteEmail(e.target.value)}
                    placeholder="name@email.com"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                    GCash / Mobile
                  </label>
                  <input
                    type="text"
                    value={invitePhone}
                    onChange={(e) => setInvitePhone(e.target.value)}
                    placeholder="0917-***-****"
                    className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Assigned Access Role
                </label>
                <select
                  value={inviteRole}
                  onChange={(e) => setInviteRole(e.target.value as CollaborationRole)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                >
                  <option value="editor">Editor (Co-manager &amp; Approver)</option>
                  <option value="contributor">Contributor (Can log &amp; comment)</option>
                  <option value="view_only">View-Only (Auditor / CPA Adviser)</option>
                  <option value="owner">Owner (Full admin rights)</option>
                </select>
              </div>

              {/* Expiring Access Toggle */}
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] space-y-2">
                <div className="flex items-center justify-between">
                  <label className="font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
                    <Clock size={14} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <span>Set Expiring Access</span>
                  </label>
                  <input
                    type="checkbox"
                    checked={inviteHasExpiry}
                    onChange={(e) => setInviteHasExpiry(e.target.checked)}
                    className="rounded accent-[#B03C09] w-4 h-4 cursor-pointer"
                  />
                </div>

                {inviteHasExpiry && (
                  <div>
                    <label className="text-[11px] text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                      Access Duration
                    </label>
                    <div className="grid grid-cols-4 gap-1.5">
                      {[
                        { days: '7', label: '7 Days' },
                        { days: '14', label: '14 Days' },
                        { days: '30', label: '30 Days' },
                        { days: '90', label: '90 Days' },
                      ].map((item) => (
                        <button
                          key={item.days}
                          type="button"
                          onClick={() => setInviteExpiryDays(item.days)}
                          className={`py-1.5 rounded-xl text-[11px] font-bold border transition-all ${
                            inviteExpiryDays === item.days
                              ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] border-transparent'
                              : 'bg-white dark:bg-[#1E1915] text-[#5A5148] dark:text-[#C6B8AC] border-[#F0D5C0] dark:border-[#383029]'
                          }`}
                        >
                          {item.label}
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              <div>
                <label className="font-bold text-[#5A5148] dark:text-[#C6B8AC] block mb-1">
                  Notes (e.g. Tax audit engagement, Boracay trip)
                </label>
                <input
                  type="text"
                  value={inviteNotes}
                  onChange={(e) => setInviteNotes(e.target.value)}
                  placeholder="Purpose of invitation"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#14100D] border border-[#F0D5C0] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              <div className="flex items-center gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsInviteMemberOpen(false)}
                  className="flex-1 py-2.5 rounded-2xl border border-[#F0D5C0] dark:border-[#383029] font-bold text-xs text-[#5A5148] dark:text-[#C6B8AC]"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 py-2.5 rounded-2xl bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] font-bold text-xs shadow-xs cursor-pointer"
                >
                  Send Invitation
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Edit Member Role */}
      {memberToEdit && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#1E1915] rounded-3xl p-5 shadow-2xl border border-[#F0D5C0] dark:border-[#383029] space-y-4">
            <h3 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
              Update {memberToEdit.name}'s Role
            </h3>

            <div className="space-y-2">
              {(['owner', 'editor', 'contributor', 'view_only'] as CollaborationRole[]).map((role) => (
                <button
                  key={role}
                  type="button"
                  onClick={() => {
                    updateMemberRole(memberToEdit.id, role);
                    setMemberToEdit(null);
                  }}
                  className={`w-full p-3 rounded-2xl text-left border font-bold text-xs capitalize flex items-center justify-between cursor-pointer transition-all ${
                    memberToEdit.role === role
                      ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] border-transparent'
                      : 'bg-white dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8] border-[#F0D5C0] dark:border-[#383029]'
                  }`}
                >
                  <span>{role.replace('_', ' ')}</span>
                  {memberToEdit.role === role && <Check size={14} />}
                </button>
              ))}
            </div>

            <button
              type="button"
              onClick={() => setMemberToEdit(null)}
              className="w-full py-2.5 rounded-2xl border border-[#F0D5C0] dark:border-[#383029] text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );

  if (isOpen !== undefined) {
    if (!isOpen) return null;
    return (
      <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
        <div
          className="fixed inset-0 bg-black/60 backdrop-blur-xs transition-opacity"
          onClick={onClose}
        />
        <div className="relative w-full max-w-xl bg-white dark:bg-[#1E1915] rounded-t-3xl sm:rounded-3xl shadow-2xl p-4 sm:p-6 border border-[#F0D5C0] dark:border-[#383029] max-h-[92vh] flex flex-col overflow-hidden animate-in slide-in-from-bottom duration-250">
          <div className="overflow-y-auto pr-1 pb-4 scrollbar-none">
            {hubContent}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4 pb-36">
      {hubContent}
    </div>
  );
};
