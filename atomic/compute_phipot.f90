!
!--------------------------------------------------------------------------
subroutine compute_phipot(lam,ik,nwf0,ns,xc)
  !--------------------------------------------------------------------------
  !
  !     This routine computes the phi functions by pseudizing the
  !     all_electron chi functions. In input it receives, the point
  !     ik where the cut is done, the angular momentum lam,
  !     and the correspondence with the all eletron wavefunction
  !
  !
  !      
  use ld1inc
  implicit none
  integer :: &
       ik,    &  ! the point corresponding to rc
       ns,    &  ! the function to pseudize
       nwf0,  &  !
       lam       ! the angular momentum
  real(kind=dp) :: &
       xc(8)
  !
  real(kind=dp), parameter :: pi=3.14159265358979d0
  real(kind=dp) :: &
       fae,    & ! the value of the all-electron function
       ff,     & ! compute the second derivative
       signo,  & ! the sign of the ae wfc
       wmax,   & !
       den,    & ! denominator
       faenor    ! the norm of the function
  real(kind=dp), external :: int_0_inf_dr, pr, d2pr, dpr

  real(kind=dp) :: &
       jnor,psnor,fact(4), f2aep,f2aem,f3ae, &
       gi(ndm),j1(ndm,4),cm(10),bm(4),ze2,cn(6),c2, &
       delta, chir(ndm,nwfx), dpoly, &
       lamda0,lamda3,lamda4,mu0,mu4,s0,s4,t0,t4, rab(ndm), &
       chi_dir(ndm,2)

  integer :: &
       i, m, n, nst, nnode, nc, nc1, ij, imax, iq

  !
  !   compute the pseudowavefunctions by expansion in spherical
  !   bessel function before r_c
  !

  ff=1.d0-dx**2/48.d0
  ze2=-zed*2.d0
  nst=(lam+1)*2
  !
  !   compute the reference wavefunction
  !
  if (new(ns)) then
     if (rel.eq.1) then
        call lschps(3,zed,exp(dx),dx,mesh,mesh,mesh, &
             1,lam,enls(ns),chir(1,ns),r,vpot)
     elseif (rel.eq.2) then
        do i=1,mesh
           rab(i)=r(i)*dx
        enddo
        call dir_outward(ndm,mesh,lam,jjs(ns),enls(ns),dx, &
             chi_dir,r,rab,vpot)
        chir(:,ns)=chi_dir(:,2)
     else
        call intref(lam,enls(ns),mesh,dx,r,r2,sqr, &
             vpot,ze2,chir(1,ns))
     endif
     !
     !    fix arbitrarely the norm at the cut-off radius equal to 0.5
     !
     jnor=chir(ik,ns)
     do n=1,mesh
        chir(n,ns)=chir(n,ns)*0.5d0/jnor
        !            write(6,*) r(n),chir(n,ns)
     enddo
  else 
     do n=1,mesh
        chir(n,ns)=psi(n,nwf0)
     enddo
  endif

  do n=1,ik+1
     gi(n)=chir(n,ns)**2
  enddo
  faenor=int_0_inf_dr(gi,r,r2,dx,ik,nst)

  call find_coefficients &
       (ik,chir(1,ns),enls(ns),r,dx,faenor,vpot,cn,c2,lam,mesh)

  !
  !   pseudowavefunction found
  !
  signo= 1.d0 !chir(ik+1,ns)/abs(chir(ik+1,ns))
  do i=1,ik
     phis(i,ns)=signo*r(i)**(lam+1)*exp(pr(cn,c2,r(i)))
  end do
  do i=ik+1,mesh
     phis(i,ns)=chir(i,ns)
  end do
  do i=1,ik
     dpoly = dpr(cn,c2,r(i))    ! first derivate of polynom
     chis(i,ns) = (enls(ns) + (2*lam+2)/r(i)*dpoly + &
          d2pr(cn,c2,r(i)) + dpoly**2)*phis(i,ns)
  enddo
  do i = ik+1,mesh
     chis(i,ns) = vpot(i,1)*phis(i,ns)
  enddo

  !      write(38,*) 'call for l=',lam,' jjs=',jjs(ns)
  !      do i=1,mesh
  !         write(38,*) r(i), phis(i,ns), chir(i,ns)
  !      enddo
  !      stop 

  return
end subroutine compute_phipot
