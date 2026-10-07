import {
  CollaborationRole,
  CollaboratorMember,
  ExpenseSplit,
  SimplifiedDebtTransfer,
  SplitMethod,
} from '../types';

/**
 * Validates whether a collaborator has active or expired access.
 */
export function checkMemberAccess(member: CollaboratorMember): {
  isExpired: boolean;
  daysRemaining: number | null;
  statusText: string;
  canManageSpaces: boolean;
  canCreateSplits: boolean;
  canApproveTransactions: boolean;
  canEditTransactions: boolean;
  canDeleteTransactions: boolean;
  canAddTransactions: boolean;
  canAddComments: boolean;
} {
  const role = member.role || 'view_only';
  let isExpired = false;
  let daysRemaining: number | null = null;
  let statusText = 'Permanent Access';

  if (member.expiresAt) {
    const now = Date.now();
    const diffMs = member.expiresAt - now;

    if (diffMs <= 0) {
      isExpired = true;
      daysRemaining = 0;
      statusText = 'Access Expired (Revoked)';
    } else {
      daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
      statusText = `Expires in ${daysRemaining} day${daysRemaining === 1 ? '' : 's'}`;
    }
  }

  const effectiveRole = isExpired ? 'view_only' : role;

  return {
    isExpired,
    daysRemaining,
    statusText,
    canManageSpaces: !isExpired && effectiveRole === 'owner',
    canCreateSplits: !isExpired && (effectiveRole === 'owner' || effectiveRole === 'editor' || effectiveRole === 'contributor'),
    canApproveTransactions: !isExpired && (effectiveRole === 'owner' || effectiveRole === 'editor'),
    canEditTransactions: !isExpired && (effectiveRole === 'owner' || effectiveRole === 'editor'),
    canDeleteTransactions: !isExpired && effectiveRole === 'owner',
    canAddTransactions: !isExpired && (effectiveRole === 'owner' || effectiveRole === 'editor' || effectiveRole === 'contributor'),
    canAddComments: !isExpired && (effectiveRole === 'owner' || effectiveRole === 'editor' || effectiveRole === 'contributor'),
  };
}

/**
 * Role-based permission matrix evaluator.
 */
export function canPerformAction(
  role: CollaborationRole,
  action:
    | 'add_tx'
    | 'edit_tx'
    | 'delete_tx'
    | 'approve_tx'
    | 'manage_members'
    | 'add_comment'
    | 'attach_receipt'
    | 'create_split'
    | 'settle_split'
    | 'delete_space'
): boolean {
  switch (role) {
    case 'owner':
      return true;
    case 'editor':
      return action !== 'delete_space' && action !== 'manage_members';
    case 'contributor':
      return (
        action === 'add_tx' ||
        action === 'add_comment' ||
        action === 'attach_receipt' ||
        action === 'create_split' ||
        action === 'settle_split'
      );
    case 'view_only':
      return false;
    default:
      return false;
  }
}

/**
 * Returns stylish badge metadata for a collaborator role.
 */
export function getRoleBadgeConfig(role: CollaborationRole): {
  label: string;
  bg: string;
  text: string;
  border: string;
  description: string;
} {
  switch (role) {
    case 'owner':
      return {
        label: 'Owner',
        bg: 'bg-amber-500/15 dark:bg-amber-500/20',
        text: 'text-amber-800 dark:text-amber-300',
        border: 'border-amber-500/30',
        description: 'Full workspace governance, member invites, approvals, and rollback privileges',
      };
    case 'editor':
      return {
        label: 'Editor',
        bg: 'bg-blue-500/15 dark:bg-blue-500/20',
        text: 'text-blue-800 dark:text-blue-300',
        border: 'border-blue-500/30',
        description: 'Can log, modify, split expenses, approve transactions, and manage receipts',
      };
    case 'contributor':
      return {
        label: 'Contributor',
        bg: 'bg-emerald-500/15 dark:bg-emerald-500/20',
        text: 'text-emerald-800 dark:text-emerald-300',
        border: 'border-emerald-500/30',
        description: 'Can log receipts, propose split expenses, add comments, and log payments',
      };
    case 'view_only':
      return {
        label: 'View-Only',
        bg: 'bg-stone-500/15 dark:bg-stone-500/20',
        text: 'text-stone-700 dark:text-stone-300',
        border: 'border-stone-500/30',
        description: 'Auditor or adviser access. Can view accounts, reports, comments, and audit logs without modifying ledger',
      };
  }
}

/**
 * Calculates individual participant share amounts based on the selected split method.
 */
export function calculateSplitShares(
  totalAmount: number,
  method: SplitMethod,
  participantIds: string[],
  customInputs?: Record<string, number> // amounts or percentages
): { memberId: string; shareAmount: number; sharePercentage?: number }[] {
  if (!participantIds.length || totalAmount <= 0) return [];

  const count = participantIds.length;

  if (method === 'equal') {
    const equalShare = Math.floor((totalAmount / count) * 100) / 100;
    const remainder = Math.round((totalAmount - equalShare * count) * 100) / 100;

    return participantIds.map((id, index) => ({
      memberId: id,
      // Give remainder cents to first participant to match total exactly
      shareAmount: index === 0 ? equalShare + remainder : equalShare,
      sharePercentage: Math.round((100 / count) * 10) / 10,
    }));
  }

  if (method === 'percentage') {
    let allocatedTotal = 0;
    const shares = participantIds.map((id, index) => {
      const pct = customInputs?.[id] ?? (100 / count);
      const isLast = index === count - 1;
      let share = Math.round((totalAmount * (pct / 100)) * 100) / 100;
      
      if (isLast) {
        // Balance out rounding discrepancies
        share = Math.max(0, Math.round((totalAmount - allocatedTotal) * 100) / 100);
      } else {
        allocatedTotal += share;
      }

      return {
        memberId: id,
        shareAmount: share,
        sharePercentage: pct,
      };
    });
    return shares;
  }

  if (method === 'fixed') {
    return participantIds.map((id) => {
      const amount = customInputs?.[id] ?? Math.round((totalAmount / count) * 100) / 100;
      return {
        memberId: id,
        shareAmount: amount,
        sharePercentage: Math.round((amount / totalAmount) * 1000) / 10,
      };
    });
  }

  // Shares / ratio (e.g. 2 shares vs 1 share)
  const totalSharesCount = participantIds.reduce((sum, id) => sum + (customInputs?.[id] || 1), 0);
  return participantIds.map((id) => {
    const sharesCount = customInputs?.[id] || 1;
    const pct = (sharesCount / totalSharesCount) * 100;
    const amount = Math.round((totalAmount * (sharesCount / totalSharesCount)) * 100) / 100;
    return {
      memberId: id,
      shareAmount: amount,
      sharePercentage: Math.round(pct * 10) / 10,
    };
  });
}

/**
 * "Who Owes Whom?" Simplification Algorithm
 * 
 * Computes net balances for all members across unsettled splits and finds the
 * minimum number of direct peer-to-peer transfers required to settle all debts.
 */
export function calculateSimplifiedDebts(
  splits: ExpenseSplit[],
  members: CollaboratorMember[]
): SimplifiedDebtTransfer[] {
  const memberNameMap = new Map<string, string>();
  members.forEach((m) => memberNameMap.set(m.id, m.name));

  // 1. Calculate net balances for each person
  // positive balance: person is owed money (creditor)
  // negative balance: person owes money (debtor)
  const netBalances = new Map<string, number>();

  splits.forEach((split) => {
    if (split.isFullySettled) return;

    const payerId = split.payerId;
    if (!netBalances.has(payerId)) netBalances.set(payerId, 0);

    split.participants.forEach((p) => {
      if (p.hasPaid) return; // already settled

      if (!netBalances.has(p.memberId)) netBalances.set(p.memberId, 0);

      if (p.memberId !== payerId) {
        // Debtor owes this amount
        netBalances.set(p.memberId, (netBalances.get(p.memberId) || 0) - p.shareAmount);
        // Payer is owed this amount
        netBalances.set(payerId, (netBalances.get(payerId) || 0) + p.shareAmount);
      }
    });
  });

  // Separate creditors and debtors
  interface BalanceNode {
    id: string;
    name: string;
    amount: number;
  }

  const creditors: BalanceNode[] = [];
  const debtors: BalanceNode[] = [];

  netBalances.forEach((balance, id) => {
    const rounded = Math.round(balance * 100) / 100;
    const name = memberNameMap.get(id) || `Member ${id.slice(0, 4)}`;

    if (rounded > 0.05) {
      creditors.push({ id, name, amount: rounded });
    } else if (rounded < -0.05) {
      debtors.push({ id, name, amount: -rounded }); // store as positive debt
    }
  });

  // Sort descending by magnitude to minimize transactions
  creditors.sort((a, b) => b.amount - a.amount);
  debtors.sort((a, b) => b.amount - a.amount);

  const transfers: SimplifiedDebtTransfer[] = [];

  let cIdx = 0;
  let dIdx = 0;

  while (cIdx < creditors.length && dIdx < debtors.length) {
    const creditor = creditors[cIdx];
    const debtor = debtors[dIdx];

    const settledAmount = Math.min(creditor.amount, debtor.amount);
    const roundedSettled = Math.round(settledAmount * 100) / 100;

    if (roundedSettled > 0) {
      transfers.push({
        fromMemberId: debtor.id,
        fromMemberName: debtor.name,
        fromName: debtor.name,
        toMemberId: creditor.id,
        toMemberName: creditor.name,
        toName: creditor.name,
        amount: roundedSettled,
        suggestedMethod: 'GCash / Maya Send Money (QR Ph)',
        reason: 'Consolidated net balance settlement',
      });
    }

    creditor.amount -= settledAmount;
    debtor.amount -= settledAmount;

    if (creditor.amount < 0.05) {
      cIdx++;
    }
    if (debtor.amount < 0.05) {
      dIdx++;
    }
  }

  return transfers;
}
