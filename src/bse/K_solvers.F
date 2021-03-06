!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
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
subroutine K_solvers(iq,Ken,Xk,q,X_static,W_bss)
 !
 use com,            ONLY:warning
 use frequency,      ONLY:w_samp
 use electrons,      ONLY:levels
 use R_lattice,      ONLY:bz_samp
 use X_m,            ONLY:X_t,Epsilon_ii,Joint_DOS,X_drude_term
 use BS_solvers,     ONLY:BSS_mode,BSS_n_descs,BSS_eval_JDOS
 use BS,             ONLY:BS_not_const_eh_f,BSE_mode,BS_K_has_been_calculated_loaded
 use parallel_m,     ONLY:master_cpu,CPU_structure
 use IO_m,           ONLY:IO_and_Messaging_switch
 use linear_algebra, ONLY:INV,DIAGO
#if defined _KERR
 use drivers,        ONLY:l_kerr
 use X_m,            ONLY:Epsilon_ij
#endif
 !
 implicit none
 type(levels) ::Ken
 type(bz_samp)::Xk,q
 type(X_t)    ::X_static
 type(w_samp) ::W_bss
 integer      ::iq
 !
 ! Work Space
 !
 logical           ::run_Haydock,run_Diago,run_inversion
 logical           ::stop_Haydock
 !
 ! Check first if the BS database has been calculated/loaded in K.F
 !
 if (.not. BS_K_has_been_calculated_loaded ) return
 !
 call section('*','BSE solver(s)')
 !
 !
 ! Solvers
 !
 run_Diago     = index(BSS_mode,'d')/=0
 run_Haydock   = index(BSS_mode,'h')/=0
 run_inversion = index(BSS_mode,'i')/=0
 !
 !
 ! I/O. All read. Only master writes.
 !
 call IO_and_Messaging_switch("+io_out",CONDITION=master_cpu)
 !
 if (run_Haydock.and.associated(Ken%W)) then
   call warning('K with QP widths not supported in the Haydock solver')
   run_Haydock=.false.
 endif
 !
 ! Diagonalization
 !
 if (run_Diago) then 
   !
   call PARALLEL_assign_LA_COMMs("Response_T_space",DIAGO,CPU_structure(4)%nCPU_lin_algebra_DIAGO)
   !
   call K_diago_driver(iq,W_bss)
   !
 endif
 !
 ! No JDOS in Inversion/Hadydock
 !
 if (BSS_eval_JDOS) deallocate(Joint_DOS)
 BSS_eval_JDOS=.FALSE.
 !
 ! Inversion
 !
 if (run_inversion) then 
   !
   call PARALLEL_assign_LA_COMMs("Response_T_space",INV,CPU_structure(4)%nCPU_lin_algebra_INV)
   !
   call K_inversion_driver(iq,W_bss,Ken,Xk,q)
   !
 endif
 !
 ! Haydock
 !
 if (run_Haydock) then
   !
   stop_Haydock = (BS_not_const_eh_f.and.index(BSE_mode,'coupling')>0)
   if (stop_Haydock) call warning('Fractional occupations and coupling still unsupported (Haydock)')
   !
   if(.not.stop_Haydock) then
     call K_output_file(iq,"open Haydock")
     call K_Haydock(iq,W_bss)
     BSS_n_descs=BSS_n_descs-4 
   endif
   !
 endif
 !
 ! CLEAN
 !
 deallocate(X_drude_term,Epsilon_ii)
#if defined _KERR
 if(l_kerr) deallocate(Epsilon_ij)
#endif
 !
end subroutine
