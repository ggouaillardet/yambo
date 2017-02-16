!
! Copyright (C) 2000-2008 A. Marini and the YAMBO team 
!              http://www.yambo-code.org
! 
! This file is distributed under the terms of the GNU 
! General Public License. You can redistribute it and/or 
! modify it under the terms of the GNU General Public 
! License as published by the Free Software Foundation; 
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will 
! be useful, but WITHOUT ANY WARRANTY; without even the 
! implied warranty of MERCHANTABILITY or FITNESS FOR A 
! PARTICULAR PURPOSE.  See the GNU General Public License 
! for more details.
!
! You should have received a copy of the GNU General Public 
! License along with this program; if not, write to the Free 
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston, 
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
module drivers
 !
 ! Generic  Drivers
 !
 logical :: list_dbs
 logical :: infile_editing
 logical :: Finite_Tel
 !
 ! Runlevels
 !
 logical :: l_setup,l_rim,l_col_cut,l_acfdt
 !
 ! Specific runlevels drivers...
 !
 ! Correlation
 !
 logical :: l_el_corr,l_ph_corr
 !
 ! QP
 !
 logical :: l_xxvxc,l_ppa,l_gw0,l_life,l_chosex
 !
 ! LR
 !
 logical :: l_optics,l_chi,l_em1d,l_em1s
 !
 ! BSE
 !
 logical :: l_bse,l_bss
 !
 ! SC
 !
 logical :: l_sc_run,l_sc_hartree,l_sc_exx,l_sc_exxc,l_sc_hf,l_sc_chosex,l_sc_pz,l_sc_lda_x
 !
 ! TDDFT
 !
 logical :: l_alda_fxc,l_bs_fxc,l_lrc_fxc
 !
end module drivers