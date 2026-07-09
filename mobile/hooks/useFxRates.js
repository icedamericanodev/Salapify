// useFxRates: fetches today's public exchange rates when the phone is online,
// caches them on the device, and hands them to the log sheet so it can pre fill
// the rate for a foreign expense. Everything degrades gracefully: offline, a
// failed fetch, or an uncovered currency all leave the user typing the rate by
// hand, so this is never load bearing for correctness.
//
// The cache is a SEPARATE AsyncStorage key, not the main data blob, so live rates
// never bloat a user's backup.

import { useEffect, useRef, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { FX_ENDPOINT, FX_MAX_AGE_MS, parseRatesResponse } from '../lib/fxrates';

const CACHE_KEY = 'salapify_fx_v1';
const FETCH_TIMEOUT_MS = 6000;

export function useFxRates(base) {
  const [state, setState] = useState({ base: null, rates: null, fetchedAt: null, loading: false });
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    const safeSet = (next) => {
      if (!cancelled && mounted.current) setState((s) => ({ ...s, ...next }));
    };

    async function run() {
      // 1. Show cached rates immediately if we have them for this base.
      let cached = null;
      try {
        const raw = await AsyncStorage.getItem(CACHE_KEY);
        if (raw) cached = JSON.parse(raw);
      } catch (e) {
        cached = null;
      }
      const haveCache = cached && cached.base === base && cached.rates && typeof cached.rates === 'object';
      if (haveCache) safeSet({ base, rates: cached.rates, fetchedAt: cached.fetchedAt || null });

      // 2. Skip the network when the cache is still fresh.
      const fresh = haveCache && cached.fetchedAt && Date.now() - cached.fetchedAt < FX_MAX_AGE_MS;
      if (fresh) return;

      // 3. Try to refresh. Any failure is silent, the user just types the rate.
      safeSet({ loading: true });
      try {
        const ctrl = new AbortController();
        const timer = setTimeout(() => ctrl.abort(), FETCH_TIMEOUT_MS);
        const res = await fetch(FX_ENDPOINT(base), { signal: ctrl.signal });
        clearTimeout(timer);
        const json = await res.json();
        const parsed = parseRatesResponse(json);
        if (parsed && parsed.rates) {
          const entry = { base, rates: parsed.rates, fetchedAt: parsed.fetchedAt || Date.now() };
          try {
            await AsyncStorage.setItem(CACHE_KEY, JSON.stringify(entry));
          } catch (e) {
            /* a full disk must never crash logging an expense */
          }
          safeSet({ base, rates: parsed.rates, fetchedAt: entry.fetchedAt, loading: false });
          return;
        }
        safeSet({ loading: false });
      } catch (e) {
        safeSet({ loading: false });
      }
    }

    run();
    return () => {
      cancelled = true;
    };
  }, [base]);

  return state;
}
