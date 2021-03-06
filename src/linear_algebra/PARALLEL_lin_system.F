!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AF
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
subroutine PARALLEL_lin_system(ORTHO,POOL,A_slk,B_slk,n,nrhs,B)
 !
 !  Solve the linear system
 !                   A X = B
 !  where A is a n-x-n matrix and B is n-x-nrhs
 !
 use pars,           ONLY:SP
 use parallel_m,     ONLY:PP_redux_wait
 use SLK_m,          ONLY:POOL_group,ORTHO_group,SLK_matrix
 use linear_algebra, ONLY:LINEAR_ALGEBRA_error,WS,LINEAR_ALGEBRA_WS_clean_up
 !
 implicit none
 !
 integer           :: n,nrhs
 type(POOL_group)  :: POOL
 type(ORTHO_group) :: ORTHO
 type(SLK_matrix)  :: A_slk, B_slk
 complex(SP)       :: B(n,nrhs)
 !
 character(64) :: subname="PARALLEL_lin_system"
 logical :: do_SLK
 !
 B=0.0_SP
 !
 do_SLK=.TRUE.
 if (ORTHO%coordinate(1)==-1) do_SLK=.FALSE.
 !
 if ( do_SLK ) then
   ! better estimate of the dimensions to be included
   if (allocated(WS%v_int)) deallocate(WS%v_int)
   allocate(WS%v_int(n+A_slk%nrows))
   !
#if defined _DOUBLE
   CALL PZGESV( n, nrhs, A_slk%blc, 1, 1, A_slk%desc, WS%v_int, B_slk%blc, 1, 1, B_slk%desc, WS%i_fail)
   if(WS%i_fail.ne.0) call LINEAR_ALGEBRA_error(subname,'performing PZGESV')
#else
   CALL PCGESV( n, nrhs, A_slk%blc, 1, 1, A_slk%desc, WS%v_int, B_slk%blc, 1, 1, B_slk%desc, WS%i_fail)
   if(WS%i_fail.ne.0) call LINEAR_ALGEBRA_error(subname,'performing PCGESV')
#endif
   !
   ! gather the solution
   !
   B(B_slk%rows(1):B_slk%rows(2),B_slk%cols(1):B_slk%cols(2))=B_slk%blc(:B_SLK%nrows_used,:B_SLK%ncols_used)
   !
 endif
 !
 call PP_redux_wait(B,COMM=POOL%INTRA_comm)
 !
 call LINEAR_ALGEBRA_WS_clean_up(WS)
 ! 
end subroutine
